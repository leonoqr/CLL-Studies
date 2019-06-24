#!/bin/bash

### ------------------------
# Version: 26.06.19
# Calculate dice for Bhanu's data
# Author: Leon Ooi
### ------------------------

declare -a roi_array=("R_Caud" "L_Caud" "R_Put" "L_Put" "R_GP" "L_GP" "R_Tha" "L_Tha")
declare -a FS_label=("50" "11" "51" "12" "52" "13" "49" "10")
declare -a DL_label=("36" "37" "57" "58" "55" "56" "59" "60")
declare -a MB_label=("8" "7" "10" "9" "12" "11" "6" "5")

# FS
FS_01="aseg_normal_native_FSSeg.nii.gz"
FS_02="aseg_atrophy_native_FSseg.nii.gz"
# DL
DL_01="MPR_AC-C01_DLseg.nii.gz"
DL_02="MPR_AC-C72_DLseg.nii.gz"
# MB
MB_01="label_v39_C01_Avanto_mprage.nii"
MB_02="label_v39_C72_Avanto_mprage.nii"

# C01
count=0
echo $'C01 Dice: \r\n' > dice_stats1.txt
for n in "${roi_array[@]}"; do
	echo "$n"
	# DL vs FS
	echo "$n " >> dice_stats1.txt
	fs_thresh=${FS_label[$count]}
	dl_thresh=${DL_label[$count]}
	fslmaths $FS_01 -uthr $fs_thresh -thr $fs_thresh -bin FS_temp
	fslmaths $DL_01 -uthr $dl_thresh -thr $dl_thresh -bin DL_temp
	fslmaths FS_temp -add DL_temp dl_overlap_temp
	fslmaths dl_overlap_temp -thr 2 -bin dl_overlap_temp
	# DL vs FS
	mb_thresh=${MB_label[$count]}
	fslmaths $MB_01 -uthr $mb_thresh -thr $mb_thresh -bin MB_temp
	flirt -in MB_temp -ref FS_temp -out MB_temp -applyxfm -usesqform
	fslmaths MB_temp -bin MB_temp
	fslmaths FS_temp -add MB_temp mb_overlap_temp
	fslmaths mb_overlap_temp -thr 2 -bin mb_overlap_temp
	fslstats FS_temp -V >> dice_stats1.txt
	fslstats DL_temp -V >> dice_stats1.txt
	fslstats MB_temp -V >> dice_stats1.txt
	fslstats dl_overlap_temp -V >> dice_stats1.txt
	fslstats mb_overlap_temp -V >> dice_stats1.txt
	echo $'\r\n' >> dice_stats1.txt
	(( count += 1 ))
done

# C72
count=0
echo $'C72 Dice: \r\n' > dice_stats2.txt
for n in "${roi_array[@]}"; do
	echo "$n"
	echo "$n " >> dice_stats2.txt
	fs_thresh=${FS_label[$count]}
	dl_thresh=${DL_label[$count]}
	fslmaths $FS_02 -uthr $fs_thresh -thr $fs_thresh -bin FS_temp
	fslmaths $DL_02 -uthr $dl_thresh -thr $dl_thresh -bin DL_temp
	fslmaths FS_temp -add DL_temp dl_overlap_temp
	fslmaths dl_overlap_temp -thr 2 -bin dl_overlap_temp
	# DL vs FS
	mb_thresh=${MB_label[$count]}
	fslmaths $MB_02 -uthr $mb_thresh -thr $mb_thresh -bin MB_temp
	flirt -in MB_temp -ref FS_temp -out MB_temp -applyxfm -usesqform
	fslmaths MB_temp -bin MB_temp	
	fslmaths FS_temp -add MB_temp mb_overlap_temp
	fslmaths mb_overlap_temp -thr 2 -bin mb_overlap_temp
	fslstats FS_temp -V >> dice_stats2.txt
	fslstats DL_temp -V >> dice_stats2.txt
	fslstats MB_temp -V >> dice_stats2.txt
	fslstats dl_overlap_temp -V >> dice_stats2.txt
	fslstats mb_overlap_temp -V >> dice_stats2.txt
	echo $'\r\n' >> dice_stats2.txt
	(( count += 1 ))
done

