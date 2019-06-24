#!/bin/bash

### ------------------------
# create masks for data
# cmd prompt: ~/Desktop/bet_w_MPR.sh -a subjects.txt -t AC3 -f -g -h -i
# Author: Leon Ooi
### ------------------------

if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi

declare -a modes
m="0"
r="0"
d="0"
p="0"
f="0"
g="0"
h="0"
i="0"
s="0"
e="0"

while getopts ":a:t:mrdpfghise" opt; do

	case $opt in
	a) IFS=$'\n'; a=($(cat $OPTARG)); echo "${#a[*]} subjects";;
	t) tp=$OPTARG; echo $tp;;
	m) m="1";;
	r) r="1";;
	d) d="1";;
	p) p="1";;
	f) f="1"; modes=("${modes[@]}" 'FA');;
	g) g="1"; modes=("${modes[@]}" 'MD');; 
	h) h="1"; modes=("${modes[@]}" 'AD');;
	i) i="1"; modes=("${modes[@]}" 'RD');;
	s) s="1"; modes=("${modes[@]}" 'SWI');;
	e) e="1";txt_name=$OPTARG;;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-m create masks"
	echo "		-r run registration"
	echo "		-d create DTI file"
	echo "		-p warp masks (must be activated for other modes to run)"
	echo "		-f fa"
	echo "		-g md"
	echo "		-h ad"
	echo "		-i rd"
	echo "		-s SWI"
	echo "		-e extract ROI values"
	exit 1;;

	*)
	echo "No argument detected"
	exit 1;;

	esac
done

if [ -z "$a" ]; then
	echo "ERROR: No subject file"
	exit 1
fi

if [ -z "$tp" ]; then
	echo "ERROR: No timepoint name"
	exit 1
fi

for x in "${a[@]}"; do
	subj_id="${tp}-${x::-1}"
	mkdir "${x::-1}_processed"
	echo "${subj_id}"
	mkdir "${x::-1}_processed/${tp}"
	cd "${x::-1}_processed/${tp}"

	echo "preparing MPRAGE image"	
	robustfov -i ../../MPR_${subj_id} -r MPR_cropped
	#standard_space_roi MPR_fov MPR_cropped

	fslswapdim ../../corr_MD_${subj_id} -x y z MD_swapped
	if 	[ "${tp::2}" = 'SO' ]; then		
	3drefit -orient PLI MD_swapped.nii.gz
	elif [ "${tp::2}" = 'AC' ]; then	
	3drefit -orient LAI MD_swapped.nii.gz
	fslswapdim MD_swapped.nii.gz -x y z MD_swapped.nii.gz
	fi	
	fslmaths ${m}_swapped.nii.gz -thr 0 ${m}_swapped.nii.gz
	~/Desktop/ants_reg.sh -i ${subj_id} -m ANTS_T12func -b MPR_cropped.nii.gz -t MD_swapped.nii.gz -r
	bet ANTS_T12func_Warped.nii.gz MPR_lowres_ex.nii.gz -m
	echo "Brain extraction - following modes to be processed: ${modes[@]}"
	for m in "${modes[@]}"; do 
	fslswapdim ../../corr_${m}_${subj_id} -x y z ${m}_swapped
	if [ "${tp::2}" = 'SO' ]; then		
	3drefit -orient PLI ${m}_swapped.nii.gz
	elif [ "${tp::2}" = 'AC' ]; then	
	3drefit -orient LAI ${m}_swapped.nii.gz
	fslswapdim ${m}_swapped.nii.gz -x y z ${m}_swapped.nii.gz
	fi

	if [ ! "${m}" = 'FA' ]; then
	fslmaths ${m}_swapped.nii.gz -thr 0 ${m}_swapped.nii.gz
	fi

	flirt -in ${m}_swapped -ref MPR_lowres_ex -out ${m}_swapped	
	fslmaths ${m}_swapped -mul MPR_lowres_ex_mask.nii.gz DTI_${subj_id}_${m}_ex
	done
	cd ..
	cd ..
done
