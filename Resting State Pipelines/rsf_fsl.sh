#!/bin/bash

### ------------------------
# Version: 26.06.19
# preprocess fmri data and perform ICA
# cmd prompt: ~/Desktop/rsf_fsl.sh -i pat_id <opts>
# Run fmri preprocessing for list of subjects using reverse phase encoding
# eg. ~/Desktop/rsf_analysis.sh -l ../Study_subjects.txt -p -f -d 1 -c
# Author: Leon Ooi
### ------------------------

if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi

p="0"
f="1"
s="1"
g="0"
d="0"
m="0"
c="0"
sr="400"
tr="3"
vol="150"
a="0"
n="25"

while getopts ":i:l:psfg:d:mco:t:v:a:n:" opt; do

	case $opt in
	i) in="$OPTARG ";;
	l) IFS=$'\n'; in=($(cat $OPTARG)); echo "${#in[*]} subject(s)";;
	p) p="1";;
	f) s="0";;
	s) f="0";;
	g) g="1";g_mode="$OPTARG";;
	d) d=$OPTARG;;
	m) m="1";;
	c) c="1";;
	o) sr=$OPTARG;;
	t) tr=$OPTARG;;
	v) vol=$OPTARG;;
	a) a="1";a_file="$OPTARG";;
	v) vol=$OPTARG;;
	n) n=$OPTARG;;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-p preprocess data"
	echo "		-f only preprocess fmri"
	echo "		-s only preprocess structural"
	echo "		-g run SIENAX for normalised GM estimation"
	echo "		-d distortion correction: 0-gre(default), 1-reverse phase encoding, 2-none"
	echo "		-m specify philips mri scanner (default siemens)"
	echo "		-c run clean up"
	echo "		-o specify physiological sampling rate <default 400Hz>"
	echo "		-t specify TR <default 3s>"
	echo "		-v specify volumes <default 150>"
	echo "		-a run MELODIC ICA"
	echo "		-n specify number of ICA components"
	exit 1;;

	:)
	echo "option -$OPTARG requires an argument"
	echo "options: 	-i single subject"
	echo "options: 	-l multiple subjects (new-line delimited text file)"
	echo "options: 	-a input MELODIC ICA file name"
	exit 1;;
	
	# use for compulsory arguments
	*)
	echo "No argument detected"
	exit 1;;

	esac
done

###################################################
# Change to subject directory
for x in "${in[@]}"; do
pat_id=${x::-1}
echo "*********** $pat_id ***************" 
cd $pat_id
mkdir tmp

###################################################
### Preprocess data

if (($p == 1)); then

## Structural preprocessing
if (($s == 1)); then

# T1 denoising and skull extraction
echo "T1 denoising and bet"
susan ${pat_id}_t1MPR 10 0.5 3 0 0 struct_denoised
bet struct_denoised struct_ext -A -B -f 0.3

# registration to MNI
echo "Registration to MNI space"
flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain -in struct_ext -out struct_reg -omat flirt_struct2MNI.mat -searchrx -180 180 -searchry -180 180
~/Desktop/ants_reg.sh -i $pat_id -m ANTS_struct2MNI -b struct_reg.nii.gz -t $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz
slicesdir -p $FSLDIR/data/standard/MNI152_T1_2mm_brain ANTS_struct2MNI_Warped.nii.gz 
echo "WM/GM/CSF segmentation for nuisance regression"
fast -t 1 -o ANTS_struct2MNI_Warped.nii.gz
fslmaths ANTS_struct2MNI_Warped_pve_0.nii.gz -thr 0.5 -bin T1_csfseg.nii.gz
fslmaths ANTS_struct2MNI_Warped_pve_1.nii.gz -thr 0.5 -bin T1_gmseg.nii.gz
fslmaths ANTS_struct2MNI_Warped_pve_2.nii.gz -thr 0.5 -bin T1_wmseg.nii.gz

fi;

###################################################
## functional preprocessing
if (($f == 1)); then

echo "WM/GM/CSF segmentation for EPI registration"
fast -t 1 -o struct_ext.nii.gz
fslmaths struct_ext_pve_2.nii.gz -thr 0.5 -bin wm_seg_epi.nii.gz

case $d in
# Option 1: Fieldmap distortion correction
0) echo "Using fieldmap for distortion correction"
if [ -z "${pat_id}_gre_mag.nii.gz" ]; then
	fslroi ${pat_id}_rsfmri fmap_mag 0 1 
else
	mv ${pat_id}_gre_mag.nii.gz fmap_mag.nii.gz
fi	
flirt -in fmap_mag.nii.gz -ref ${pat_id}_gre_pha -out fmap_mag -applyxfm -usesqform
bet fmap_mag.nii.gz fmap_mag_brain1.nii.gz
fslmaths fmap_mag_brain1.nii.gz -ero fmap_mag_brain.nii.gz
fsl_prepare_fieldmap SIEMENS ${pat_id}_gre_pha fmap_mag_brain.nii.gz fmap_rads.nii.gz 7.38
base_rsf="${pat_id}_rsfmri"	
;;
# Option 2: Reverse phase encoded distortion correction
1) echo "Using reverse phase encoded image for distortion correction"	
fslroi	${pat_id}_rsf_PA bup 0 1
fslroi ${pat_id}_rsfmri bdown 0 1 
fslmerge -t b_combined bup bdown
echo "Applying topup"
topup --imain=b_combined.nii.gz --datain=../../acqparams.txt --config=b02b0.cnf --out=topup_out
applytopup --imain=${pat_id}_rsfmri --topup=topup_out --datain=../../acqparams.txt --inindex=1 --method=jac --out=rsf_dist_corr
base_rsf="rsf_dist_corr.nii.gz"
;;

2) echo "No correction method"
base_rsf="${pat_id}_rsfmri";;
	
esac

# slice timing correction and motion correction
echo "Slice timing correction and motion correction - checking for SMS_timing file in study directory"

if [ -f "../../SMS_timing.txt" ]; then
	echo "With SMS - Siemens"
	slicetimer -i ${base_rsf} -o rsf.nii.gz --tcustom=../../SMS_timing.txt	
else
	case $m in
	# siemens scanner
	0)echo "Without SMS - Siemens"
	slicetimer -i ${base_rsf} -o rsf.nii.gz -r ${tr} --odd;;
	# philips scanner
	1)echo "Without SMS - Philips"
	slicetimer -i ${base_rsf} -o rsf.nii.gz -r ${tr};;
	esac 
fi

# removal of first 5 TRs
echo "Removing first 5 TRs"
fslroi	rsf rsf_trimmed 5 "$(($vol-5))"
mcflirt -in rsf_trimmed -out rsf_mcf -plots
mv rsf_mcf.par ${pat_id}_rsfmri_mcf.par
bet rsf_mcf rsf_bet -m -F

# despiking and grand mean scaling
echo "Despiking and grand mean scaling"
fsl_motion_outliers -i rsf_bet -o dvars.dvars --dvars -p dvars_graph -s dvars.txt -m rsf_bet_mask --nomoco
fslmaths rsf_mcf -mas rsf_bet_mask rsf_mcf_bet
glob_mean_float="$(fslstats rsf_mcf_bet -M)"
glob_mean=${glob_mean_float%.*}
fslmaths rsf_mcf_bet -div $glob_mean -mul 10000 rsf_scaled


# BBR registration
case $d in

0) echo "BBR using fieldmaps"
epi_reg --echospacing=0.000325 --wmseg=wm_seg_epi.nii.gz --fmap=fmap_rads.nii.gz  --fmapmag=fmap_mag.nii.gz --fmapmagbrain=fmap_mag_brain.nii.gz --pedir=y --epi=rsf_trimmed.nii.gz --t1=struct_denoised.nii.gz --t1brain=struct_ext.nii.gz --out=func2struct_posy;;

1) echo "BBR without fieldmaps"
epi_reg --echospacing=0.0025 --wmseg=wm_seg_epi.nii.gz --pedir=y \
 --epi=rsf_trimmed.nii.gz --t1=struct_denoised.nii.gz \
--t1brain=struct_ext.nii.gz --out=func2struct_posy;;

2) echo "FLIRT resampling"
flirt -in rsf_trimmed -ref struct_denoised -out func2struct_posy -applyxfm -usesqform;;

esac


flirt -in func2struct_posy -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain -out rsf_MNI_rigid -init flirt_struct2MNI.mat -applyxfm
antsApplyTransforms -d 3 -e 3 -i rsf_MNI_rigid.nii.gz -r $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -o func_MNI.nii.gz --transform [ANTS_struct2MNI_0GenericAffine.mat,0] --transform ANTS_struct2MNI_1Warp.nii.gz

# nuisance signal regression
echo "Nuisance signal regression"
fslmeants -i func_MNI -o csf_reg.txt -m T1_csfseg.nii.gz 
fslmeants -i func_MNI -o wm_reg.txt -m T1_wmseg.nii.gz 
# mcf,card,w,c,d,n,s,TR
matlab -nodisplay -r "addpath('/media/sf_FSL_Files/rsfMRI'); glm_matrix('${pat_id}_rsfmri_mcf.par','wm_reg.txt','csf_reg.txt','dvars.txt',5,${sr},${tr}); quit"
fsl_glm -i func_MNI.nii.gz -d reg_design.txt -o betas --demean --out_res=func_clean.nii.gz

# Spatial smoothing
echo "Spatial smoothing and bandpass filtering" # std = FWHM(in mm)/2.3548
fslmaths func_clean -kernel gauss 2.54799 -fmean func_smth
fslmaths func_smth -bptf 0.009 0.1 func_filtered

fi;

fi;

###################################################
## run SIENAX
if (($g == 1)); then
	echo "Running SIENAX on denoised structural image"
	if (($g_mode == 1)); then
	echo "Running pre-registration to MNI"
	flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm -in struct_denoised -out skull_reg -searchrx -180 180 -searchry -180 180
	sienax skull_reg -o SIENAX	
	elif (($g_mode == 2)); then
		echo "WARNING: Using stricter parameters for BET (please run part 1 for flirt registered image first"
		sienax skull_reg -o SIENAX -B "-g -0.2"
	fi;
fi;

###################################################
### Cleanup files

if (($c == 1)); then
echo "Running clean up of intermediate files"
rm ANTS_struct2MNI_Warped_* struct_ext_*
rm fmap* func2struct_* rsf*
rm func_smth* func_clean*
fi;

###################################################

cd ..
done

###################################################
### Melodic ICA
if (($a == 1)); then
echo "Running MELODIC"
echo "Generating list of subjects"
	echo $(ls -1 */func_filtered.nii.gz| wc -l)" subjects files with func_filtered"
	echo $'\n' > all_sub.txt
	ls -1 */func_filtered.nii.gz >> all_sub.txt
	echo "Running ICA with ${n} components"
	melodic -i all_sub.txt -o ${a_file} --tr=${tr} --nobet --bgthreshold=1 -a concat --bgimage=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -m $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz --report --Oall -d ${n}
fi;

###################################################
