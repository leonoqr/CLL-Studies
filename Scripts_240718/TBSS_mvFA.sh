#!/bin/bash

### ------------------------
# move FA files to TBSS directory before processing
# cmd prompt: ~/Desktop/TBSS_mvFA.sh file_name (eg. ~/Desktop/TBSS_mvFA.sh 3b0_only)
# Author: Leon Ooi
### ------------------------

#newdir=$1
file_n=$1
ls -A
file_arr=(*)

#declare -a arr=("Normalise" "Prescan")
declare -a arr=("TP1" "TP2/Normalise" "TP2/Prescan")
declare -a short=("TP1_N" "TP2_N" "TP2_P")
mkdir -p /media/sf_FSL_Files/ExploreDTI_no_prescan_no61/A/TBSS_$1/FA
mkdir -p /media/sf_FSL_Files/ExploreDTI_no_prescan_no61/B/TBSS_$1/FA
mkdir -p /media/sf_FSL_Files/ExploreDTI_no_prescan_no61/C/TBSS_$1/FA

for dir in "${file_arr[@]}"; do
    	echo $dir
	protocol=${dir: -1}
	#echo $protocol
	#if [ $protocol == "C" ]; then
	count=0		
	for i in "${arr[@]}"
	do	
		cd $dir/$i
		pwd
		cp $1_DTI_FA.nii.gz /media/sf_FSL_Files/ExploreDTI_no_prescan_no61/$protocol/TBSS_$1
		cd /media/sf_FSL_Files/ExploreDTI_no_prescan_no61/$protocol/TBSS_$1
		pwd
		mv $1_DTI_FA.nii.gz ${dir}_${short[count]}.nii.gz
		let "count++"		
		cd ..
		cd ..
	done
	#fi
done

#tbss_non_FA $1
#tbss_1_preproc *.nii.gz
#tbss_2_reg -T
#tbss_3_postreg -S
#tbss_4_prestats 0.2
#Text2Vest
#randomise -i all_FA_skeletonised -o tbss_AB -m mean_FA_skeleton_mask -d design.mat -t designAB.con -n 500 --T2
#randomise -i all_FA_skeletonised -o tbss_BA -m mean_FA_skeleton_mask -d design.mat -t designBA.con -n 500 --T2
#fsleyes $FSLDIR/data/standard/MNI152_T1_1mm mean_FA_skeleton -cm Green -dr 0.2 0.7 tbss_AB_tfce_corrp_tstat1 -cm Red-Yellow -dr 0.95 1
#cluster -i tbss_BA_tfce_corrp_tstat1.nii.gz -t 0.95 --mm -o A_FA_cluster
#fslmaths -dt A_FA_cluster -thr 1 -uthr 1 -bin A_FA_cluster
#atlasquery -a "JHU White-Matter Tractography Atlas" -m tbss_BA_tfce_corrp_tstat1
