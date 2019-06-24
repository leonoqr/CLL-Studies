#!/bin/bash

### ------------------------
# Version: 26.06.19
# registration from T1 to MNI using ants
# cmd prompt: ~/Desktop/ants_reg.sh -i pat_id -m T1_2_MNI -b MPRAGE -t MNI_template
# option -r rigid -a affine -s full registration
# Author: Leon Ooi
### ------------------------

if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi

declare -a flags=("a" "r" "s" "i" "m" "b" "t")
aflag="0"
rflag="0"
sflag="0"
iflag="0"
mflag="0"
bflag="0"
tflag="0"

while getopts ":i:m:b:t:ars" opt; do
	case $opt in
	i) fil=$OPTARG;iflag="1";;
	m) mode=$OPTARG;mflag="1";;
	b) t1brain=$OPTARG;bflag="1";;
	t) template=$OPTARG;tflag="1";;
	a) aflag="1";;
	r) rflag="1";;
	s) sflag="1";;
	
	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-m registration modality selection"
	echo "		-b file to be registered"
	echo "		-t template for registration"
	echo "		-a affine transformation only"
	echo "		-s diffeomorphic structure registration"
	exit 1;;

	*)
	echo "No argument detected"
	exit 1;;

	esac
done

if [ -z "$fil" ] || [ -z "$mode" ] || [ -z "$t1brain" ] || [ -z "$template" ]; then
	echo -n "ERROR: Input file missing for"
	for m in "${flags[@]}"; do
		if ((${m}flag == 0)); then	
			echo -n " -$m "
		fi;
	done 
	echo ""
	exit 1
fi

# https://github.com/ANTsX/ANTs/wiki/Anatomy-of-an-antsRegistration-call
# histogram matching = 1 for same modality, 0 for cross modality
# moving transform = 0 midpoint, 1 center of mass, 2 point of origin
# removed brain lesion mask
#cd $fil
echo "******** $fil ********"
if (($rflag == 1)); then
echo "ANTs registration (rigid only)... "
antsRegistration -d 3 -r [ $template, $t1brain, 1 ] \
      -m mattes[ $template, $t1brain, 1, 32, regular, 0.3] \
        -t rigid[ 0.1 ] \
        -c [100x100x200, 1.e-8,20] \
        -s 4x2x1vox \
        -f 3x2x1 -l 1 \
	-o [${mode}_,${mode}_Warped.nii.gz]

elif (($aflag == 1)); then
echo "ANTs registration (affine only)... "
antsRegistration -d 3 -r [ $template, $t1brain, 1 ] \
      -m mattes[ $template, $t1brain, 1, 32, regular, 0.3] \
        -t affine[ 0.1 ] \
        -c [100x100x200, 1.e-8,20] \
        -s 4x2x1vox \
        -f 3x2x1 -l 1 \
	-o [${mode}_,${mode}_Warped.nii.gz]

elif (($sflag == 1)); then
echo "ANTs registration (structure)... "
antsRegistration -d 3 -r [ $template, $t1brain, 1 ] \
      -m mattes[ $template, $t1brain, 1, 32, regular, 0.3] \
        -t affine[ 0.1 ] \
        -c [100x100x200, 1.e-8,20] \
        -s 2x1x0.5vox \
        -f 3x2x1 -l 1 \
      -m cc[ $template, $t1brain, 1, 4] \
        -t SyN[ .20, 3, 0] \
        -c [100x100x50, 0, 5] \
        -s 1x0.5x0vox \
        -f 4x2x1 -l 1 -u 1 -z 1\
      -o [${mode}_,${mode}_Warped.nii.gz]

else
echo "ANTs registration (full)... "
antsRegistration -d 3 -r [ $template, $t1brain, 1 ] \
      -m mattes[ $template, $t1brain, 1, 32, regular, 0.3] \
        -t affine[ 0.1 ] \
        -c [100x100x200, 1.e-8,20] \
        -s 4x2x1vox \
        -f 3x2x1 -l 1 \
      -m cc[ $template, $t1brain, 1, 4] \
        -t SyN[ .20, 3, 0] \
        -c [100x100x50, 0, 5] \
        -s 1x0.5x0vox \
        -f 4x2x1 -l 1 -u 1 -z 1\
      -o [${mode}_,${mode}_Warped.nii.gz]
fi



# ********************* UNUSED *********************
#antsRegistration --dimensionality 3 --float 0 \
#	--output [$thisfolder\${mode},${mode}_Warped.nii.gz] \
#	--interpolation Linear \
#	--winsorize-image-intensities [0.005,0.995] \
#	--use-histogram-matching 1 \
#	--initial-moving-transform [$t1brain,$template,1] \
#	--transform Rigid[0.1] --metric MI[$t1brain,$template,1,32,Regular,0.25] \
#	--convergence [1000x500x250x100,1e-6,10] --shrink-factors 8x4x2x1 \
#	--smoothing-sigmas 3x2x1x0vox \
#	--transform Affine[0.1] --metric MI[$t1brain,$template,1,32,Regular,0.25] \
#	--convergence [1000x500x250x100,1e-6,10] --shrink-factors 8x4x2x1 \
#	--smoothing-sigmas 3x2x1x0vox \
#	--transform SyN[0.1,3,0] --metric CC[$t1brain,$template,1,4] \
#	--convergence [100x70x50x20,1e-6,10] --shrink-factors 8x4x2x1 \
#	--smoothing-sigmas 3x2x1x0vox

# match dimensions
#echo "resizing warped image"
#flirt -in T1_2_MNI_Warped.nii.gz -ref $FSLDIR/data/standard/MNI152_T1_1mm_brain -out T1_2_MNI_Warped_flirt.nii.gz -omat resize_mat
# ********************* UNUSED *********************
