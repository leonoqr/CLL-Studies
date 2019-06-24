#!/bin/bash

### ------------------------
# preprocess fmri data
# cmd prompt: ~/Desktop/rsf_analysis.sh -i pat_id <opts> (eg. ~/Desktop/rsf_analysis.sh -i PALS-44 -p -g -r -c)
# Author: Leon Ooi
### ------------------------

if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi

p="0"
g="0"
r="0"
a="0"
c="0"
d="0"
e="0"
tr="2.5"

while getopts ":i:pg:rac:d:et:" opt; do

	case $opt in
	i) in=$OPTARG;;
	p) p="1";;
	g) g="1";gflag=$OPTARG;;
	r) r="1";;
	a) a="1";;
	c) c="1"
	   c_suffix=$OPTARG;;
	d) d="1"
	   d_suffix=$OPTARG;;
	e) e="1";;
	t) tr=$OPTARG;;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-p preprocess data"
	echo "		-g regress data <1 - create RVT regressors, 2 - FAST, 3 - AFNI regression>"
	echo "		-r run registration"
	echo "		-c complete remaining pipeline: warp masks and regress"
	echo "		-a run single session ICA"
	echo "		-d display SCA results"
	echo "		-e use existing temp file" 
	echo "		-t specify TR <default 2.5>"
	exit 1;;

	:)
	echo "option -$OPTARG requires an argument"
	exit 1;;
	
	# use for compulsory arguments
	*)
	echo "No argument detected"
	exit 1;;

	esac
done

###################################################
# CHECK INPUT AND CHANGE DIRECTORY
if [ -z "$in" ]; then
	echo "ERROR: No input file"
	echo "usage ~/Desktop/rsf_analysis.sh -i <file_name> <opts>"
	echo "options: 	-p preprocess data"
	echo "		-g regress data"
	echo "		-r run registration <1 - create RVT regressors, 2 - FAST, 3 - AFNI regression>"
	echo "		-c complete remaining pipeline: warp masks and regress"
	echo "		-a run single session ICA"
	echo "		-d display SCA results" 
	echo "		-e use existing temp file"
	echo "		-t specify TR <default 2.5>"	 
	exit 1
fi


# change to subject directory
pat_id=$2;
echo "***********$pat_id***************" 
cd $pat_id
mkdir tmp

# functional areas for processing
declare -a arr=("PCC" "vis_c" "hand")

###################################################
# PREPROCESS FUNCTIONAL AND STRUCTURAL DATA

if (($p == 1)); then
	# copy essential files if tmp option is on	
	if (($e == 1)); then
		echo "preprocessing: extract files from temp"
		cp tmp/3DAX_unextracted.nii.gz tmp/rsf_unprocessed.nii.gz .
	fi;
	echo "preprocessing: correcting FOV for registration"	
	# robust fov
	robustfov -i 3DAX_unextracted.nii.gz -r 3DAX_robust
	echo "preprocessing: brain extraction"	
	# brain extraction for fmri
	bet rsf_unprocessed.nii.gz rsf_b.nii.gz -F
	# brain extraction for 3dax
	bet 3DAX_robust.nii.gz 3DAX.nii.gz -f 0.3
	echo "preprocessing: slice timing correction"
	# slice timing correction 
	#slicetimer -i rsf_b.nii.gz -o rsf.nii.gz -r $tr --odd # needs to be changed for siemens vs phillips

	echo "multiband - slice timing skipped for now"
	cp rsf_b.nii.gz rsf.nii.gz

	# data sorting and cleaning
	rm rsf_b.nii.gz
	mv 3DAX_unextracted.nii.gz 3DAX_robust.nii.gz rsf_b_mask.nii.gz rsf_unprocessed.nii.gz tmp

# **************** UNUSED ****************	 
	# motion correction + spatial smoothing + temporal smoothing
	# mcflirt -in rsf_s.nii.gz -o rsf_mcf.nii.gz -refvol 1
	# gaussian blurring
	# std = FWHM(in mm)/2.3548
	#fslmaths rsf_mcf.nii.gz -kernel gauss 2.1233226 -fmean rsf_smth.nii.gz
# **************** UNUSED ****************

fi

###################################################
# REGISTER FUNC TO T1 AND T1 TO MNI

if (($r == 1)); then

	# motion correction and flirt (initial transformation guess)
	echo "registration: creating linear transform (fMRI - T1)"
	# registration from whole_func to highres *Can be improved
	flirt -in 3DAX.nii.gz -ref rsf.nii.gz -in rsf.nii.gz -out DAX2fMRI -omat DAX2fMRI.mat
	#convert_xfm -omat DAX2fMRI.mat -inverse fMRI2DAX.mat
	
# **************** UNUSED ****************
	# FSL registration from highres to standard
	#flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -in 3DAX.nii.gz -cost normcorr -out DAX2MNI -omat DAX2MNI.mat

	# FSL fnirt and warps
	#echo "registration in process: creating non-linear transforms"
	#fnirt --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz --in=3DAX.nii.gz --aff=DAX2MNI.mat --cout=warp2MNI
	#invwarp -w warp2MNI.nii.gz -o MNI2DAX.nii.gz -r 3DAX.nii.gz

# **************** UNUSED ****************


	# registration using ANTS
	echo "registration: ANTs registration (T1 - MNI)"
	echo "registration: check slicesdir before continuing!"
	~/Desktop/ants_reg.sh -i $pat_id -m ANTS_DAX2MNI -b 3DAX.nii.gz -t $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz
	slicesdir -p $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz ANTS_DAX2MNI_Warped.nii.gz 
fi

###################################################
# REGRESSION OF NUISANCE VARIABLES

if (($g == 1)); then
	if (($gflag == 1)); then
	# AFNI preprocessing
	# create RVT regressors
	echo "regression: creating physiological regressors (RetroTS)..."
	# siemens settings - -p 496
	# phillips settings - -p 400
	RetroTS.py -r txt_resp.txt -c txt_puls.txt -p 400 -n 57 -v $tr -prefix RVT_puls
	((gflag += 1))
	fi;

	if (($gflag == 2)); then	
	#create segmentation files	
	echo "regression: running FAST..."
	if (($e == 1)); then
		echo "regression: extracting existing FAST files"
		cp tmp/AFNI_files/anat+orig* tmp/AFNI_files/rsf+orig* .
		cp tmp/segmentation/3DAX_pve_1.nii.gz tmp/segmentation/3DAX_pve_0.nii.gz .
	else
		fast -t 1 -o 3DAX.nii.gz
		3dWarp -deoblique -prefix anat 3DAX.nii.gz
 		3dWarp -deoblique -prefix rsf rsf.nii.gz
	fi;	
 	fslmaths 3DAX_pve_1.nii.gz -thr 0.5 -bin WM_thresh
 	fslmaths 3DAX_pve_0.nii.gz -thr 0.5 -bin CSF_thresh
 	flirt -in WM_thresh.nii.gz -ref rsf.nii.gz -out WM_reg -init DAX2fMRI.mat -applyxfm
 	flirt -in CSF_thresh.nii.gz -ref rsf.nii.gz -out CSF_reg -init DAX2fMRI.mat -applyxfm
	fslchfiletype NIFTI WM_reg.nii.gz CSF_reg.nii.gz 
 	3dWarp -deoblique -prefix WM WM_reg.nii 
 	3dWarp -deoblique -prefix CSF CSF_reg.nii
	mkdir tmp/segmentation
	mv 3DAX_*.nii.gz WM_*.nii.gz CSF_*.nii.gz tmp/segmentation
	#resample and create masks 
	echo "regression: creating masks"	
	3dresample -master rsf+orig -inset WM+orig -prefix WM_resampled
 	3dresample -master rsf+orig -inset CSF+orig -prefix CSF_resampled
 	3dmaskave -quiet -mask WM_resampled+orig rsf+orig > WM_Timecourse.1D
 	3dmaskave -quiet -mask CSF_resampled+orig rsf+orig > CSF_Timecourse.1D
	#1d_tool.py -infile 'WM_Timecourse.1D' -censor_first_trs 3 -write WM_rem_Timecourse.1D
	#1d_tool.py -infile 'CSF_Timecourse.1D' -censor_first_trs 3 -write CSF_rem_Timecourse.1D
	((gflag += 1))
	fi; 
	
	if (($gflag == 3)); then 
	if (($e == 1)); then
		cp tmp/regressors/*.1D tmp/AFNI_files/*.BRIK tmp/AFNI_files/*.HEAD .
	fi;
	echo "regression: regressing physiological noise"
	echo "WARNING: previous preproc files will be removed"
	rm -r preproc	 

	
	# old afni preprocessing pipeline - not supported anymore	
	#afni_restproc.py -anat anat+orig -epi rsf+orig -rvt RVT_puls.slibase.1D -dest regressor WM_Timecourse.1D -regressor CSF_Timecourse.1D preproc -prefix pre
	#afni_restproc.py -anat anat+orig -epi rsf+orig -rvt RVT_ecg.slibase.1D -regressor WM_Timecourse.1D -regressor CSF_Timecourse.1D -dest preproc_ecg -prefix pre
# **************** UNUSED ****************
	
	# create regression script, remove one if already exists
	rm proc.$pat_id output.proc.$pat_id
	rm -r $pat_id.results
	afni_proc.py -subj_id $pat_id -dsets rsf+orig -copy_anat anat+orig \
	-blocks despike ricor tshift align volreg blur mask regress \
	-tcat_remove_first_trs 3 -ricor_regs_nfirst 3 \
	-ricor_regs RVT_puls.slibase.1D -volreg_align_e2a \
	-regress_anaticor -blur_size 6 \
	-regress_motion_per_run -regress_censor_motion 0.2 \
	-regress_bandpass 0.01 0.1 -regress_apply_mot_types demean deriv \
	-regress_run_clustsim no -regress_est_blur_epits -regress_est_blur_errts

	# run regression script and save results to file
	tcsh -xef proc.$pat_id |& tee output.proc.$pat_id

# **************** UNUSED ****************
	((gflag += 1))	
	fi;

	if (($gflag == 4)); then 
	echo "regression: renaming and moving of files"	
	# resample and rename file
	rm clean_resampled+orig.*
	3dresample -master rsf.nii.gz -inset ${pat_id}.results/errts.${pat_id}.anaticor+orig -prefix clean_resampled
	#3dresample -master rsf.nii.gz -inset preproc/pre.cleanEPI+orig -prefix clean_resampled  	
	3dAFNItoNIFTI -prefix rsf_filtered clean_resampled+orig
	mkdir tmp/AFNI_files	
	mv *.BRIK *.HEAD tmp/AFNI_files
	mkdir tmp/regressors	
	mv *.1D tmp/regressors	

	# bandpass filtering
	#fslmaths clean_rsf.nii -bptf 0.01 0.15 rsf_filtered.nii.gz
	fi

fi

###################################################
# RUN ICA

if (($a == 1)); then
	
	melodic -i rsf.nii -o ICA --tr $tr --report

# **************** STILL IN WORKS ****************
	# cd ICA
	# fslregfilt -i filtered func -o denoised data -d filtered_func.ica/melodic_mix -f "x,x,x"

	# after running ICA in gui
	#flirt -in melodic_IC.nii.gz -ref $FSLDIR/data/standard/MNI152_T1_2mm -out melodic_flirted -applyxfm -init ../reg/example_func2standard.mat
	#fsleyes $FSLDIR/data/standard/MNI152_T1_2mm melodic_flirted -cm red-yellow -dr 2 8

fi

###################################################
# TRANSFORM MASKS TO SUBJECT SPACE AND RUN SINGLE SESSION DUAL REGRESSION

if (($c == 1)); then

	echo "calculation in progress: warp masks and run dual regression"
	if (($e == 1)); then
		cp tmp/ANTS_* .
	fi;	
	for n in "${arr[@]}"
	do
		mask=$n
		echo $n
		# warp mask to functional space
		antsApplyTransforms -d 3 -i /media/sf_FSL_Files/rsfMRI/Masks/${mask}.nii.gz -r 3DAX.nii.gz -o ANTS_${mask}.nii.gz --transform ANTS_DAX2MNI_1InverseWarp.nii.gz --transform [ANTS_DAX2MNI_0GenericAffine.mat,1]
		# resample resolution
		flirt -ref rsf.nii.gz -in ANTS_${mask}.nii.gz -out ANTS_f_${mask}.nii.gz -applyxfm -usesqform
		# applywarp -i /media/sf_FSL_Files/rsfMRI/Masks/${mask}.nii.gz -r rsf.nii -o ${mask}_func --postmat=DAX2fMRI.mat -w MNI2DAX.nii.gz
		# thin mask by using binary threshhold
		fslmaths ANTS_f_${mask}.nii.gz -bin ${mask}_func.nii.gz
		# time series extraction
		fslmeants -i rsf_filtered.nii.gz -o ${mask}.txt -m ${mask}_func.nii.gz
		# seed based correlation
		dual_regression ${mask}_func.nii.gz 0 -1 0 SCA_${c_suffix}_${mask} rsf_filtered.nii.gz
	done
	mv ANTS_*.nii.gz tmp		
	mv ${mask}.txt tmp
fi

###################################################
# DISPLAY RESULTS

if (($d == 1)); then
	echo "---displaying results---"
	for n in "${arr[@]}"; do
	#echo "displaying: $n"
	fsleyes 3DAX.nii.gz SCA_${d_suffix}_${n}/dr_stage2_subject00000.nii.gz -cm green -dr 1 3 ${n}_func.nii.gz -cm yellow &
	done

fi
	#fsleyes 3DAX.nii.gz SCA_DR_PCC/dr_stage2_subject00000.nii.gz -cm green -dr 1 3 PCC_func.nii.gz -cm yellow

###################################################


