#!/bin/bash

### ------------------------
# create masks for data
# cmd prompt: ~/Desktop/1.5T_create_masks.sh -a subjects.txt -t AC3 <opts>
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
DTI="0"

while getopts ":a:t:mrdpfghise" opt; do

	case $opt in
	a) IFS=$'\n'; a=($(cat $OPTARG)); echo "${#a[*]} subjects";;
	t) tp=$OPTARG; echo $tp;;
	m) m="1";;
	r) r="1";;
	d) d="1";;
	p) p="1";;
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

# save all basal ganglia masks from std space into file named masks
declare -a first_arr=("L_Caud" "L_Pall" "L_Puta" "L_Thal" "R_Caud" "R_Pall" "R_Puta" "R_Thal")
declare -a bg_arr=("L_atl_Caud" "L_atl_Pal" "L_atl_Put" "L_atl_Tha" "R_atl_Caud" "R_atl_Pal" "R_atl_Put" "R_atl_Tha")
declare -a sn_arr=("L_atl_SN" "R_atl_SN" "L_atl_RN" "R_atl_RN")
#declare -a sn_arr=("L_atl_SN" "R_atl_SN" "L_atl_RN" "R_atl_RN" "L_atl_GPe" "R_atl_GPe" "L_atl_GPi" "R_atl_GPi")
declare -a total_arr=("${bg_arr[@]}" "${sn_arr[@]}")
mask_dir="/media/sf_FSL_Files/basal_ganglia/masks/"


mkdir registration_results 

###################################################
# -m create masks
if (($m == 1)); then
	echo "----------Option m: creating masks----------" 
	# SN mask need to downsample first
	for i in "${bg_arr[@]}"; do
		echo $i
		fslmaths ${mask_dir}/$i -thr 95 -bin ${mask_dir}/${i}_downsized
	done

	for i in "${sn_arr[@]}"; do
		echo "$i - resampling..."
		# resample to 1mm
		flirt -in ${mask_dir}/$i -ref $FSLDIR/data/standard/MNI152_T1_1mm_brain -out ${mask_dir}/${i}_resampled -applyxfm -usesqform
		fslmaths ${mask_dir}/${i}_resampled -thr 7 -bin ${mask_dir}/${i}_downsized
		rm ${mask_dir}/${i}_resampled.nii.gz
	done
fi

###################################################

for x in "${a[@]}"; do
	subj_id="${tp}-${x::-1}"
	mkdir "${x::-1}_processed"
	echo "${subj_id}"
	mkdir "${x::-1}_processed/${tp}"
	cd "${x::-1}_processed/${tp}"

###################################################
# -d create diffusion file << dont use this>>
# consider making script just for diffusion processing
if (($d == 1)); then 
	echo "----------Option d: creating diffusion file----------"
	echo "Eddy correction..."
	eddy_correct ../../DTI_${subj_id}.nii.gz DTI_EC.nii.gz 0
	rm DTI_EC_tmp*.nii.gz
	echo "Brain extraction..."
	bet DTI_EC.nii.gz DTI_BET.nii.gz -m -F
	bet DTI_EC.nii.gz DTI_nodiff_BET.nii.gz -m
	echo "produce DTI images"
	dtifit -k DTI_BET.nii.gz -o DTI_index -m DTI_BET.nii.gz -r ../../standard.bvec -b ../../standard.bval --verbose
	mv DTI_index_FA.nii.gz DTI_${subj_id}_FA_ex.nii.gz
	mv DTI_index_MD.nii.gz DTI_${subj_id}_MD_ex.nii.gz
	mv DTI_index_L1.nii.gz DTI_${subj_id}_AD_ex.nii.gz
	fslmaths DTI_index_L2.nii.gz -add DTI_index_L3.nii.gz DTI_${subj_id}_RD_ex.nii.gz
	fslmaths DTI_${subj_id}_RD_ex.nii.gz -div 2 DTI_${subj_id}_RD_ex.nii.gz
fi

###################################################
# -r run registration
if (($r == 1)); then

	echo "----------Option r: run registration----------"
	###################################################
	echo "registration: preprocessing for registration"
	robustfov -i ../../MPR_${subj_id}.nii.gz -r MPR_cropped
	#robustfov -i MPR_cropped -r MPR_cropped
	#standard_space_roi MPR_cropped MPR_cropped
	bet MPR_cropped.nii.gz MPR_extracted.nii.gz	
	###################################################
	# registration from DTI to T1
	if (($DTI == 1)); then
		# use MD for time being
		echo "registration: linear registration from T1 to DTI using MD"
		if (($d == 0)); then 	
		fslswapdim ../../corr_MD_${subj_id} -x y z MD_swapped
		# different for AC and SOS
		if [ "${tp::2}" = 'SO' ]; then		
		3drefit -orient PRI MD_swapped.nii.gz
		elif [ "${tp::2}" = 'AC' ]; then
		#3drefit -orient PLI MD_swapped.nii.gz
		3drefit -orient PRI MD_swapped.nii.gz
		#fslswapdim MD_swapped.nii.gz -x y z MD_swapped.nii.gz
		fi
		fslmaths MD_swapped.nii.gz -thr 0 MD_swapped.nii.gz
		~/Desktop/ants_reg.sh -i ${subj_id} -m ANTS_T12func_unex -b MPR_cropped.nii.gz -t MD_swapped.nii.gz -r

		bet ANTS_T12func_unex_Warped.nii.gz MPR_lowres_ex.nii.gz -m
		echo "Brain extraction - following modes to be processed: ${modes[@]}"
		for m in "${modes[@]}"; do 
		fslswapdim ../../corr_${m}_${subj_id} -x y z ${m}_swapped
		if [ "${tp::2}" = 'SO' ]; then
			if [ "${m}" = 'FA' ]; then
				3drefit -orient RAI ${m}_swapped.nii.gz
				~/Desktop/ants_reg.sh -i ${subj_id} -m FA_swapped -b FA_swapped.nii.gz -t MD_swapped.nii.gz -r
				rm FA_swapped.nii.gz
				mv FA_swapped_Warped.nii.gz FA_swapped.nii.gz
			else
				3drefit -orient PRI ${m}_swapped.nii.gz
			fi
		elif [ "${tp::2}" = 'AC' ]; then
		#3drefit -orient PLI ${m}_swapped.nii.gz
		3drefit -orient PRI ${m}_swapped.nii.gz
		#fslswapdim ${m}_swapped.nii.gz -x y z ${m}_swapped.nii.gz
		fi
		fslmaths ${m}_swapped.nii.gz -thr 0 ${m}_swapped.nii.gz	
		fslmaths ${m}_swapped -mul MPR_lowres_ex_mask.nii.gz DTI_${subj_id}_${m}_ex
		done
		fi
	
		~/Desktop/ants_reg.sh -i ${subj_id} -m ANTS_T12func -b MPR_extracted.nii.gz -t DTI_${subj_id}_MD_ex.nii.gz -r
		cp ANTS_T12func_Warped.nii.gz MPR_lowres_ex.nii.gz
		slicesdir -p DTI_${subj_id}_MD_ex.nii.gz ANTS_T12func_Warped.nii.gz
	fi


	# find SWI transform
	if (($s == 1)); then
	echo "registration: resampling SWI to DTI data"
		bet ../../swi_${subj_id} SWI_extracted -m
		~/Desktop/ants_reg.sh -i ${subj_id} -m ANTS_SWI2DTI -b SWI_extracted.nii.gz -t DTI_${subj_id}_MD_ex.nii.gz -r
		mv ANTS_SWI2DTI_Warped.nii.gz DTI_${subj_id}_SWI_ex.nii.gz
	fi
	
	cd ..	
	if [ ! -d 'ANTS_REG' ]; then
		echo "registration: no existing ANTs directory - making one"
		mkdir ANTS_REG
		cp ${tp}/MPR_extracted.nii.gz ANTS_REG
		# save base registration file		
		cd ANTS_REG
		mv MPR_extracted.nii.gz MPR_base.nii.gz
		cd ..
	fi
	echo "registration: finding linear transform to template"
	cd ${tp}
	flirt -ref ../ANTS_REG/MPR_base -in MPR_extracted -out T1_2_template.nii.gz -omat T1_2_template.mat
	convert_xfm -omat template_2_T1.mat -inverse T1_2_template.mat	
	cd ..
	if [ -f 'ANTS_REG/ANTS_MPR2MNI_Warped.nii.gz' ]; then
	    	echo "Existing ANTs warp exists, skipping ANTs T1_2_std registration!"
	else
		echo "Registration: running ANTs"
		~/Desktop/ants_reg.sh -i ${subj_id} -m ANTS_MPR2MNI -b ${tp}/MPR_extracted.nii.gz -t $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz
		cp ANTS_MPR2MNI_Warped.nii.gz ../registration_results
		cd ../registration_results ANTS_MPR2MNI_Warped.nii
		mv ANTS_MPR2MNI_Warped.nii.gz ${x::-1}_MPRAGE.nii.gz
		cd ../${x::-1}_processed/
		mv ANTS_MPR2MNI_Warped.nii.gz ANTS_MPR2MNI_0GenericAffine.mat ANTS_MPR2MNI_1InverseWarp.nii.gz ANTS_MPR2MNI_1Warp.nii.gz ANTS_REG
	fi
	cd ${tp}
fi;
###################################################

# warp mask to each individual
if (($p == 1)); then 
	echo "----------Option p: warp masks in individuals----------"	
	if [ ! -d '../ANTS_REG' ]; then
		echo "Missing ANTs directory - please process ANTs before warping masks!"
	else
		for mask in "${bg_arr[@]}"; do
		# std to subj template
		antsApplyTransforms -d 3 -i ${mask_dir}/${mask}_downsized.nii.gz -r ../ANTS_REG/MPR_base.nii.gz -o ANTS_${mask}.nii.gz --transform ../ANTS_REG/ANTS_MPR2MNI_1InverseWarp.nii.gz --transform [../ANTS_REG/ANTS_MPR2MNI_0GenericAffine.mat,1]
		# subj template to subj tp
		flirt -ref MPR_extracted.nii.gz -in ANTS_${mask}.nii.gz -out ANTS_${mask}.nii.gz -applyxfm -init template_2_T1.mat
		# subj tp to subj tp functional
		antsApplyTransforms -d 3 -i ANTS_${mask}.nii.gz -r MPR_lowres_ex.nii.gz -o ANTS_${mask}.nii.gz --transform [ANTS_T12func_0GenericAffine.mat,0]
		# binarize mask
		fslmaths ANTS_${mask} -thr 0.5 -bin ${mask}_warped
		echo "$mask warping completed"
		done

		for mask in "${sn_arr[@]}"; do
		antsApplyTransforms -d 3 -i ${mask_dir}/${mask}_downsized.nii.gz -r ../ANTS_REG/MPR_base.nii.gz -o ANTS_${mask}.nii.gz --transform ../ANTS_REG/ANTS_MPR2MNI_1InverseWarp.nii.gz --transform [../ANTS_REG/ANTS_MPR2MNI_0GenericAffine.mat,1]
		flirt -ref MPR_extracted.nii.gz -in ANTS_${mask}.nii.gz -out ANTS_${mask}.nii.gz -applyxfm -init template_2_T1.mat
		antsApplyTransforms -d 3 -i ANTS_${mask}.nii.gz -r MPR_lowres_ex.nii.gz -o ANTS_${mask}.nii.gz --transform [ANTS_T12func_0GenericAffine.mat,0]
		fslmaths ANTS_${mask} -thr 0.5 -bin ${mask}_warped
		echo "$mask warping completed"
		done
	fi
fi
###################################################

# extract BG values
if (($e == 1)); then

	echo "----------Option e: processing BG values----------"
	if [ ! -d '../ANTS_REG' ]; then
		echo "Missing ANTs folder - please process ANTs before processing BG values!"
	else
	echo "writing to text files for: ${modes[@]}"
	for m in "${modes[@]}"; do
		echo $'Tract\r\n' > BG_${m}_${subj_id}.txt

		for mask in "${total_arr[@]}"; do
			echo "$mask: " >> BG_${m}_${subj_id}.txt
			fslmeants -i DTI_${subj_id}_${m}_ex -m ${mask}_warped.nii.gz >> BG_${m}_${subj_id}.txt
		echo $'\r\n' >> BG_${m}_${subj_id}.txt
	done
		mv BG_${m}_${subj_id}.txt ..
	done

	fi
fi
###################################################
	cd ..	
	cd ..
done

if (($r == 1)); then
echo "---------- creating slicesdir ----------"
slicesdir *_processed/ANTS_REG/MPR_base.nii.gz
cd registration_results
slicesdir -p $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz *_MPRAGE.nii.gz
cd ..
fi
###################################################


