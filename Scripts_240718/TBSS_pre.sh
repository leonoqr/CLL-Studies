#!/bin/bash

### ------------------------
# preprocess TBSS
# cmd prompt: ~/Desktop/TBSS_pre.sh file_basename (eg. ~/Desktop/TBSS_pre.sh 3b0_only)
# Author: Leon Ooi
### ------------------------

t_mark="1"

mkdir Uncorrected_files
file_arr=($(ls -d ${1}*))

for dir in "${file_arr[@]}"; do
	file_name=${dir:: -4}
	echo ${file_name}
	### - find protocol - only for PALS ###
	# echo ${dir}
	# i_p=${dir: -2}
	# protocol=${i_p: 0: 1}
	# echo $protocol
	#if [ $protocol == "C" ]; then	
	#count=0
	#######################################	
	
	#for i in "${arr[@]}"; do
		#cd ${dir}/$i #check this
		#pwd

		cd Uncorrected_files
		mkdir DTI_$file_name
		cd DTI_$file_name
		cp ../../$dir .
		echo "Eddy correction..."
		eddy_correct ${dir} ${file_name}_EC.nii.gz 0
		echo "Brain extraction..."
		bet ${file_name}_EC.nii.gz ${file_name}_BET.nii.gz -m -F
		bet ${file_name}_EC.nii.gz ${file_name}_nodiff_BET.nii.gz -m
		echo "produce DTI images"
		dtifit -k ${file_name}_BET.nii.gz -o ${file_name}_DTI -m ${file_name}_BET_mask -r ../../standard.bvec -b ../../standard.bval --verbose
		

		#let "count++"
		cd ..
		dti_path=DTI_${file_name}/${file_name}_DTI
		cp ${dti_path}_FA.nii.gz ${dti_path}_MD.nii.gz ${dti_path}_L1.nii.gz ${dti_path}_L2.nii.gz ${dti_path}_L3.nii.gz .

		mv ${file_name}_DTI_FA.nii.gz corr_FA_${dir}.gz
		mv ${file_name}_DTI_MD.nii.gz corr_MD_${dir}.gz
		mv ${file_name}_DTI_L1.nii.gz corr_AD_${dir}.gz
		fslmaths  ${file_name}_DTI_L2 -add ${file_name}_DTI_L3 ${file_name}_added
		fslmaths ${file_name}_added -div 2 corr_RD_${dir}	
		fslchfiletype NIFTI corr_FA_${dir}.gz 
		fslchfiletype NIFTI corr_AD_${dir}.gz 
		fslchfiletype NIFTI corr_RD_${dir}.gz 
		fslchfiletype NIFTI corr_MD_${dir}.gz
		rm ${file_name}_DTI_L2.nii.gz ${file_name}_DTI_L3.nii.gz ${file_name}_added.nii.gz 
		cd ..
		#if [ $count -gt 1 ]; then
		#	cd ..
		#fi
	#done
	#fi
done

