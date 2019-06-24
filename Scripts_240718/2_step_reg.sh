#!/bin/bash

### ------------------------
# preprocess fmri data
# cmd prompt: ~/Desktop/2_step_reg.sh func struc template (eg. ~/Desktop/rsf_analysis.sh rsf.nii.gz MPR.nii.gz $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz)
# Author: Leon Ooi
### ------------------------

func=$1
struc=$2
if [ -z "$3" ]; then
	MNI=$3
else; then
	MNI=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz
fi



# motion correction and flirt (initial transformation guess)
	echo "registration: creating linear transform (func - T1)"
	# registration from whole_func to highres *Can be improved
	flirt -ref 3DAX.nii.gz -in rsf.nii.gz -out fMRI2DAX -omat fMRI2DAX.mat
	convert_xfm -omat struc2func.mat -inverse func2struc.mat
	
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
	~/Desktop/ants_reg.sh -i $pat_id -m ANTS_DAX2MNI -b 3DAX.nii.gz -t $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz
	slicesdir -p $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz ANTS_DAX2MNI_Warped.nii.gz 
