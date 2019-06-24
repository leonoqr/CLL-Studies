#!/bin/bash

### ------------------------
# create masks for data
# cmd prompt: ~/Desktop/create_masks.sh -i pat_id -m -r (eg. ~/Desktop/create_masks.sh -i folder_name -m -r)
# Author: Leon Ooi
### ------------------------

if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi

m="0"
r="0"
d="0"
f="0"
s="DTI_Index_FA"
n="1"

while getopts ":i:mdfrsn" opt; do

	case $opt in
	i) in=$OPTARG;;
	m) m="1";;
	r) r="1";;
	d) d="1";;
	f) f="1";;
	s) s="SWI";;
	n) n="0";;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-m create masks"
	echo "		-r run registration"
	echo "		-d create DTI file"
	echo "		-f use FIRST"
	echo "		-s register to SWI data"
	echo "		-n save masks to NII compressed format"
	exit 1;;

	*)
	echo "No argument detected"
	exit 1;;

	esac
done

# save all basal ganglia masks from std space into file named masks
declare -a first_arr=("L_Caud" "L_Pall" "L_Puta" "L_Thal" "R_Caud" "R_Pall" "R_Puta" "R_Thal")
declare -a bg_arr=("L_atl_Caud" "L_atl_Pal" "L_atl_Put" "L_atl_Tha" "R_atl_Caud" "R_atl_Pal" "R_atl_Put" "R_atl_Tha")
declare -a sn_arr=("L_atl_SN" "R_atl_SN" "L_atl_RN" "R_atl_RN" "L_atl_GPe" "R_atl_GPe" "R_atl_GPe" "R_atl_GPi")
declare -a total_arr=("${bg_arr[@]}" "${sn_arr[@]}") 


###################################################

if [ -z "$in" ]; then
	echo "ERROR: No input file"
	exit 1
fi
	folder=$2;
	echo "***********$folder***************" 
	cd $folder

###################################################
# -m create masks
if (($m == 1)); then
	echo "----------Option m: creating masks----------" 
	# SN mask need to downsample first
	for i in "${bg_arr[@]}"; do
		echo $i
		fslmaths /media/sf_FSL_Files/basal_ganglia/masks/$i -thr 95 -bin /media/sf_FSL_Files/basal_ganglia/masks/${i}_downsized
	done

	for i in "${sn_arr[@]}"; do
		echo "$i - resampling..."
		# resample to 1mm
		flirt -in /media/sf_FSL_Files/basal_ganglia/masks/$i -ref $FSLDIR/data/standard/MNI152_T1_1mm_brain -applyxfm -usesqform -out /media/sf_FSL_Files/basal_ganglia/masks/${i}_resampled -applyxfm
		fslmaths /media/sf_FSL_Files/basal_ganglia/masks/${i}_resampled -thr 8 -bin /media/sf_FSL_Files/basal_ganglia/masks/${i}_downsized
		rm /media/sf_FSL_Files/basal_ganglia/masks/${i}_resampled.nii.gz
	done
fi

###################################################
# -d create diffusion file
if (($d == 1)); then 
	echo "----------Option d: creating diffusion file----------"
	echo "Eddy correction..."
	eddy_correct DTI.nii.gz DTI_EC.nii.gz 0
	rm DTI_EC_tmp*.nii.gz
	echo "Brain extraction..."
	bet DTI_EC.nii.gz DTI_BET.nii.gz -m -F
	bet DTI_EC.nii.gz DTI_nodiff_BET.nii.gz -m
	echo "produce DTI images"
	dtifit -k DTI_BET.nii.gz -o DTI_index -m DTI_nodiff_BET.nii.gz -r DTI.bvec -b DTI.bval --verbose
fi

###################################################
# -f use FIRST
if (($f == 1)); then 
	echo "----------Option f: running FIRST----------"	
	run_first_all -i MPR_extracted.nii.gz -b -s L_Caud,L_Pall,L_Puta,L_Thal,R_Caud,R_Pall,R_Puta,R_Thal -o first_bg
	# check for errors
	cat first_bg.logs/*.e*
	# check registration
	echo "create slicesdir"
	slicesdir -p $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz MPR_extracted_to_std_sub.nii.gz
	# check segmentation
	# auto-extract all masks
	echo "binarize FIRST masks"
	for i in "${first_arr[@]}"; do
		echo $i
		first_utils --meshToVol -m first_bg-${i}_first.vtk -i MPR_extracted.nii.gz -l 1 -o ${i}_first_mask.nii.gz
		fslmaths ${i}_first_mask.nii.gz -uthr 100 -bin ${i}_first_mask.nii.gz
	done
fi

###################################################
# -r run registration
if (($r == 1)); then
	###################################################
	robustfov -i MPR.nii.gz -r MPR_cropped
	bet MPR_cropped.nii.gz MPR_extracted.nii.gz
	###################################################
	echo "----------Option r: run registration----------"
	echo "registration in process..."	
	# registration from DTI to T1
	flirt -ref MPR_extracted.nii.gz -in ${s} -out func_2_T1 -omat func_2_T1.mat

# **************** UNUSED ****************	
	# registration from highres to standard
	#flirt -ref $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz -in MPR_extracted.nii.gz -out T1_2_MNI -omat T1_2_MNI.mat
	#convert_xfm -omat T1_2_func.mat -inverse func_2_T1.mat
	# fnirt and warps
	#fnirt --ref=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz --in=MPR_extracted.nii.gz --aff=T1_2_MNI.mat --cout=warp2MNI
	#invwarp -w warp2MNI.nii.gz -o MNI_2_T1.nii.gz -r MPR.nii.gz
# **************** UNUSED ****************

	~/Desktop/ants_reg.sh -i $folder -m ANTS_MPR2MNI -b MPR_extracted.nii.gz -t $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz
	slicesdir -p $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz ANTS_MPR2MNI_Warped.nii.gz 

fi;
###################################################

# warp mask to each individual
echo "----------warping atlas masks to subject----------"
for m in "${total_arr[@]}"; do
	rm ${m}_warped*	
	echo $m
	antsApplyTransforms -d 3 -i /media/sf_FSL_Files/basal_ganglia/Masks/${m}.nii.gz -r MPR_extracted.nii.gz -o ANTS_${m}.nii.gz --transform ANTS_MPR2MNI_1InverseWarp.nii.gz --transform [ANTS_MPR2MNI_0GenericAffine.mat,1]
	# resample resolution
	flirt -ref ${s}.nii.gz -in ANTS_${m}.nii.gz -out ANTS_f_${m}.nii.gz -applyxfm -usesqform
	#applywarp -i /media/sf_FSL_Files/basal_ganglia/masks/${m}_downsized.nii.gz -r ${s} -o ${m}_warped --postmat=T1_2_func.mat -w MNI_2_T1.nii.gz
	fslmaths ANTS_f_${m} -thr 95 -bin ${m}_warped
	if (($n == 1)); then	
		fslchfiletype NIFTI ${m}_warped
	fi;
done

mkdir ANTS_masks
mv ANTS_*_atl_* ANTS_masks


