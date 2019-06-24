# ~/Desktop/do_all.sh

~/Desktop/ants_reg.sh -i test -m ANTS_T12temp -b MPR_extracted.nii.gz -t ../ANTS_REG/MPR_base.nii.gz -r

modes=('FA' 'MD' 'AD' 'RD')
mask_dir="/media/sf_FSL_Files/basal_ganglia/masks/"
declare -a bg_arr=("R_atl_Caud" "L_atl_Caud" "L_atl_Pal" "L_atl_Put" "L_atl_Tha" "R_atl_Caud" "R_atl_Pal" "R_atl_Put" "R_atl_Tha")
declare -a sn_arr=("L_atl_SN" "R_atl_SN" "L_atl_RN" "R_atl_RN")

	echo "----------Option p: warp masks in individuals----------"	
	if [ ! -d '../ANTS_REG' ]; then
		echo "Missing ANTs directory - please process ANTs before warping masks!"
	else
		for mask in "${bg_arr[@]}"; do
		# std to subj template
		antsApplyTransforms -d 3 -i ${mask_dir}/${mask}_downsized.nii.gz -r ../ANTS_REG/MPR_base.nii.gz -o ANTS_${mask}.nii.gz --transform ../ANTS_REG/ANTS_MPR2MNI_1InverseWarp.nii.gz --transform [../ANTS_REG/ANTS_MPR2MNI_0GenericAffine.mat,1]
		# subj template to subj tp
		antsApplyTransforms -d 3 -i ANTS_${mask}.nii.gz -r MPR_extracted.nii.gz -o ANTS_${mask}.nii.gz --transform [ANTS_T12temp_0GenericAffine.mat,1]
		# subj tp to subj tp functional
		antsApplyTransforms -d 3 -i ANTS_${mask}.nii.gz -r MPR_lowres_ex.nii.gz -o ANTS_${mask}.nii.gz --transform [ANTS_T12func_0GenericAffine.mat,0]
		# binarize mask
		fslmaths ANTS_${mask} -thr 0.1 -bin ${mask}_warped
		echo "$mask warping completed"
		done

		for mask in "${sn_arr[@]}"; do
		antsApplyTransforms -d 3 -i ${mask_dir}/${mask}_downsized.nii.gz -r ../ANTS_REG/MPR_base.nii.gz -o ANTS_${mask}.nii.gz --transform ../ANTS_REG/ANTS_MPR2MNI_1InverseWarp.nii.gz --transform [../ANTS_REG/ANTS_MPR2MNI_0GenericAffine.mat,1]
		antsApplyTransforms -d 3 -i ANTS_${mask}.nii.gz -r MPR_extracted.nii.gz -o ANTS_${mask}.nii.gz --transform [ANTS_T12temp_0GenericAffine.mat,1]
		antsApplyTransforms -d 3 -i ANTS_${mask}.nii.gz -r MPR_lowres_ex.nii.gz -o ANTS_${mask}.nii.gz --transform [ANTS_T12func_0GenericAffine.mat,0]
		fslmaths ANTS_${mask} -thr 0.1 -bin ${mask}_warped
		echo "$mask warping completed"
		done
	fi

