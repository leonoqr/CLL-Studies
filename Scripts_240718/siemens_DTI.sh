#!/bin/bash

m="0"
r="0"
f="0"
g="0"
h="0"
i="0"
s="0"
e="0"

while getopts ":a:t:bmrfghise" opt; do

	case $opt in
	a) IFS=$'\n'; a=($(cat $OPTARG)); echo "${#a[*]} subjects";;
	t) tp=$OPTARG; echo $tp;;
	m) m="1";;
	r) r="1";;
	f) f="1"; modes=("${modes[@]}" 'FA');DTI="1";;
	g) g="1"; modes=("${modes[@]}" 'MD');DTI="1";; 
	h) h="1"; modes=("${modes[@]}" 'AD');DTI="1";;
	i) i="1"; modes=("${modes[@]}" 'RD');DTI="1";;
	s) s="1"; modes=("${modes[@]}" 'SWI');;
	e) e="1";;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-m create masks"
	echo "		-r run registration"
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

declare -a bg_arr=("L_Tha" "R_Tha" "L_Caud" "R_Caud" "L_Put" "R_Put" "L_GP" "R_GP")

#####################################
for x in "${a[@]}"; do
	subj_id="${tp}-${x::-1}"
	mkdir "${x::-1}_processed"
	echo "${subj_id}"
	mkdir "${x::-1}_processed/${tp}"
	cd "${x::-1}_processed/${tp}"
#####################################
# make individual masks for Siemens
	if (($m == 1)); then
		declare -i count=5
		#subj="label/label_v40_${x::-1}_TrioTim_mprage"
		subj="SOS/label_v39_AVANTO1_${x::-1}"
		#subj="AC/label_v39_${x::-1}_Avanto_mprage"
		for i in "${bg_arr[@]}"; do
			fslmaths ../../Siemens_Masks/$subj -thr "$count" -uthr "$count" -bin ${i}_s
			echo "${i} - ${count}"			
			((count++))
		done
	fi

#####################################
# resample mask to lowres DTI image
	if (($r == 1)); then
		for i in "${bg_arr[@]}"; do
			antsApplyTransforms -d 3 -i ${i}_s.nii.gz -r MPR_lowres_ex.nii.gz -o ${i}_s_reg.nii.gz --transform [ANTS_T12func_0GenericAffine.mat,0]
			fslmaths ${i}_s_reg.nii.gz -thr 0.95 -bin ${i}_s_reg.nii.gz
		done	
	fi

#####################################
# extract BG values
	if (($e == 1)); then
		echo "writing to text files for: ${modes[@]}"
		for met in "${modes[@]}"; do
			echo $'Tract\r\n' > S_BG_${met}_${subj_id}.txt
			for mask in "${bg_arr[@]}"; do
				echo "$mask: " >> S_BG_${met}_${subj_id}.txt
				fslmaths DTI_${subj_id}_${met}_ex -mas ${mask}_s_reg.nii.gz temp			
				fslstats temp -M >> S_BG_${met}_${subj_id}.txt
				#echo ',' >> S_BG_${met}_${subj_id}.txt
				fslstats temp -S >> S_BG_${met}_${subj_id}.txt 
				echo $'\r\n' >> S_BG_${met}_${subj_id}.txt
			done
			rm temp.nii.gz
			mv S_BG_${met}_${subj_id}.txt ..
		done
	fi

	cd ../..
done
