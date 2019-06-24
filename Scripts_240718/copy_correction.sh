#!/bin/bash

# call: ~/Desktop/copy_correction.sh C01
declare -a bg_arr=("L_atl_Caud" "L_atl_Pal" "L_atl_Put" "L_atl_Tha" "R_atl_Caud" "R_atl_Pal" "R_atl_Put" "R_atl_Tha")
declare -a sn_arr=("L_atl_SN" "R_atl_SN" "L_atl_RN" "R_atl_RN")
declare -a total_arr=("${bg_arr[@]}" "${sn_arr[@]}")


subj=$1

AC3_subj="${subj}_processed/AC3"

declare -a timepoints=("SOS3")
echo "Processing for ${subj}"
echo "Copying AC3 masks to: ${timepoints[@]}"
#declare -a timepoints=("SOS3" "AC" "SOS")

for t in "${timepoints[@]}"; do
	subj_path="${subj}_processed/${t}"
	cd $subj_path
	~/Desktop/ants_reg.sh -i ${subj} -m AC3_2_${t} -b ../AC3/MPR_lowres_ex.nii.gz -t MPR_lowres_ex.nii.gz -r
	for i in "${total_arr[@]}"; do
		rm ${i}_warped.nii.gz
		cp ../AC3/${i}_warped.nii.gz .
		antsApplyTransforms -d 3 -i ${i}_warped.nii.gz -r MPR_lowres_ex.nii.gz -o ${i}_warped.nii.gz --transform [AC3_2_${t}_0GenericAffine.mat,0]
		fslmaths ${i}_warped.nii.gz -bin ${i}_warped.nii.gz		
	done
	cd ..
done

