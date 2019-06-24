#!/bin/bash

### ------------------------
# create new folder and extract individual values
# cmd prompt: ~/Desktop/TBSS_extract.sh metric (eg. ~/Desktop/TBSS_extract.sh L1)
# Author: Leon Ooi
### ------------------------

#tbss_non_FA $1
#tbss_1_preproc *.nii.gz
#tbss_2_reg -T
#tbss_3_postreg -S
#tbss_4_prestats 0.2
#Text2Vest design.txt design.mat
#randomise -i all_FA_skeletonised -o tbss_AB -m mean_FA_skeleton_mask -d design.mat -t designAB.con -n 500 --T2
#randomise -i all_FA_skeletonised -o tbss_BA -m mean_FA_skeleton_mask -d design.mat -t designBA.con -n 500 --T2
#fsleyes $FSLDIR/data/standard/MNI152_T1_1mm mean_FA_skeleton -cm Green -dr 0.2 0.7 tbss_AB_tfce_corrp_tstat1 -cm Red-Yellow -dr 0.95 1
#cluster -i tbss_BA_tfce_corrp_tstat1.nii.gz -t 0.95 --mm -o A_FA_cluster
#fslmaths -dt A_FA_cluster -thr 1 -uthr 1 -bin A_FA_cluster
#atlasquery -a "JHU White-Matter Tractography Atlas" -m tbss_BA_tfce_corrp_tstat1

metric=$1
declare -a roi_array=("ATR_L" "ATR_R" "CC" "CIN_L" "CIN_R" "IFO_L" "IFO_R" "ILF_L" "ILF_R" "SLF_L" "SLF_R" "PLIC_L" "PLIC_R")
mkdir indiv_proc
mkdir indiv_proc/$metric
cp all_${metric}.nii.gz indiv_proc/${metric}
declare -i sub="$(fslnvols all_${metric}.nii.gz)"
### only 1 TP
#((sub=sub/2))
### 2 TPs
((sub=sub/3))
echo $sub "subjects"
cd indiv_proc
cd $metric
for i in $(seq 1 $sub)
do
	echo "$i"/$sub
	
	### only 1 TP
	#((norm_n=$i*2-2))
	#((pre_n=$i*2-1))
	#fslroi all_${metric}.nii.gz Norm_temp $norm_n 1
	#fslroi all_${metric}.nii.gz Pre_temp $pre_n 1
	#echo $'Tract\r\n' > Norm_${metric}_$i.txt
	#echo $'Tract\r\n' > Pre_${metric}_$i.txt
	
	### 2 TPs
	((TP1_norm_n=$i*3-3))
	((TP2_norm_n=$i*3-2))
	((TP2_pre_n=$i*3-1))
	fslroi all_${metric}.nii.gz TP1_Norm_temp $TP1_norm_n 1
	fslroi all_${metric}.nii.gz TP2_Norm_temp $TP2_norm_n 1
	fslroi all_${metric}.nii.gz TP2_Pre_temp $TP2_pre_n 1
	echo $'Tract\r\n' > TP1_n_${metric}_$i.txt
	echo $'Tract\r\n' > TP2_n_${metric}_$i.txt
	echo $'Tract\r\n' > TP2_p_${metric}_$i.txt
	
	for n in "${roi_array[@]}"
	do
		echo "$n: " >> TP1_n_${metric}_$i.txt
		fslmeants -i TP1_Norm_temp.nii.gz -m /media/sf_FSL_Files/ExploreDTI_w_prescan/mask/$n.nii.gz >> TP1_n_${metric}_$i.txt
		echo $'\r\n' >> TP1_n_${metric}_$i.txt
		
		echo "$n: " >> TP2_n_${metric}_$i.txt
		fslmeants -i TP2_Norm_temp.nii.gz -m /media/sf_FSL_Files/ExploreDTI_w_prescan/mask/$n.nii.gz >> TP2_n_${metric}_$i.txt
		echo $'\r\n' >> TP2_n_${metric}_$i.txt
		
		### for 2nd TP
		echo "$n: " >> TP2_p_${metric}_$i.txt
		fslmeants -i TP2_Pre_temp.nii.gz -m /media/sf_FSL_Files/ExploreDTI_w_prescan/mask/$n.nii.gz >> TP2_p_${metric}_$i.txt
		echo $'\r\n' >> TP2_p_${metric}_$i.txt
	done
	
	### only 1 TP
	#rm Norm_temp.nii.gz
	#rm Pre_temp.nii.gz
	### 2 TPs
	rm TP1_Norm_temp.nii.gz
	rm TP2_Norm_temp.nii.gz
	rm TP2_Pre_temp.nii.gz
done


