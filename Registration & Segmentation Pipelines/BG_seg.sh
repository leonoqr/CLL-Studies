#!/bin/bash

### ------------------------
# Version: 24.06.19
# Segment BG structures
# cmd prompt: ~/Desktop/BG_seg.sh -i pat_id <opts>
# Process DTI data, segment BG structures and extract BG DTI values
# eg. ~/Desktop/BG_seg.sh -l ../Study_subjects.txt -p -f -t 2
# Author: Leon Ooi
### ------------------------

# Input file directory
if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi

p="0"
a="0"
f="0"
g="0"
e="0"
s="0"
t="0"
z="0"
c="0"
v="0"
vmode="0"
d="0"

while getopts ":i:l:paefgst:z:cv:d" opt; do

	case $opt in
	i) in="$OPTARG ";;
	l) IFS=$'\n'; in=($(cat $OPTARG)); echo "${#in[*]} subject(s)";;
	p) p="1";;
	a) a="1";;
	e) e="1";;
	f) f="1";;
	g) g="1";;
	s) s="1";;
	t) t="1";tmode=$OPTARG;;
	z) z="1";zmode=$OPTARG;;
	c) c="1";; #custom QSM sampling
	v) v="1";vmode=$OPTARG;;
	d) d="1";;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-i input individual subject"
	echo "options: 	-l input multiple subjects (text file)"
	echo "options: 	-p preprocess DTI data"
	echo "options: 	-e existing files from AC_SOS correction"
	echo "options: 	-a ANTs atlas warping"
	echo "options: 	-f FIRST BG segmentation"
	echo "options:	-g run SIENAX"
	echo "options: 	-s Freesurfer segmentation"
	echo "options: 	-t 1: sample values only; 2: sample + transform masks to DTI space"
	echo "options: 	-z specify timepoint"
	echo "options: 	-v 1: vertex analysis 2: volume extraction"
	echo "options: 	-d longitudinal analysis (z against z-1)"
	;;

	:)
	echo "option -$OPTARG requires an argument"
	exit 1;;
	
	# use for compulsory arguments
	*)
	echo "No argument detected"
	exit 1;;

	esac
done

if [ -z "$in" ]; then
	echo "WARNING: No subject file"
fi

declare -a first_arr=("L_Caud" "L_Pall" "L_Puta" "L_Thal" "R_Caud" "R_Pall" "R_Puta" "R_Thal")
declare -a first_label=("11" "13" "12" "10" "50" "52" "51" "49")
declare -a freesurfer_label=("11" "13" "12" "10" "50" "52" "51" "49")
declare -a sn_arr=("L_atl_SN" "R_atl_SN")
declare -a modes=("FA" "MD" "AD" "RD")
declare -a limits=("1000" "2000" "2000" "2000")

#######################################################################
for x in "${in[@]}"; do
	subj_id="${x::-1}"
	echo "--------$subj_id--------"
	if (($z == 1)); then
		cd $subj_id/TP${zmode}
	else
		cd $subj_id
	fi
	if [ -f "struct_crop.nii.gz" ]; then
	echo "WARNING: Cropped image exists, using for processing instead"
	struct_img="struct_crop"
	else
	struct_img="${subj_id}_t1MPR"
	fi
#######################################################################
	### preprocess data	
	if (($p == 1)); then
	echo "p) Preprocess data"
	bet ${subj_id}_DTI ${subj_id}_bet -r 100 -m
	if (($e == 0)); then		
	# DTI data
	eddy_correct ${subj_id}_DTI ${subj_id}_EC 0
	dtifit -k ${subj_id}_EC -o ${subj_id} -m ${subj_id}_bet_mask -r ${subj_id}_DTI.bvec -b ${subj_id}_DTI.bval
	else
	echo "e) Existing AC_SOS correction, skipping eddy correction and dtifit"
	fslmaths ${subj_id}_L1 -mul 1 ${subj_id}_AD
	fslmaths ${subj_id}_L2 -add ${subj_id}_L3 -div 2 ${subj_id}_RD 	
	for m in "${modes[@]}"; do
		if ((${m} = "FA")); then
			fslmaths ${subj_id}_FA -thr 0 -uthr 1000 ${subj_id}_FA
		else			
			fslmaths ${subj_id}_${m} -thr 0 -uthrP 99.9 ${subj_id}_${m}
		fi
	done
	fi
	# Structural data
	echo "Registering DTI to structural image and brain extraction"
	flirt -ref ${struct_img} -in ${subj_id}_FA -out DTI_reg -omat flirt_DTI2struct.mat -dof 6
	flirt -in ${subj_id}_bet_mask -ref ${struct_img} -out ${subj_id}_betmask_highres -applyxfm -init flirt_DTI2struct.mat
	fslmaths ${subj_id}_betmask_highres -bin ${subj_id}_betmask_highres
	fslmaths ${struct_img} -mul ${subj_id}_betmask_highres struct_ext
	bet struct_ext struct_ext
	# move DTI files
	echo "Creating file to store DTI extra DTI files"	
	mkdir DTI
	mv ${subj_id}_L*.nii.gz ${subj_id}_V*.nii.gz ${subj_id}_MO.nii.gz ${subj_id}_S0.nii.gz ${subj_id}.* DTI
	fi
#######################################################################
	### ANTS atlas warping	
	if (($a == 1)); then
	echo "a) ANTS Warping"
	maskdir='/media/sf_FSL_Files/basal_ganglia/masks'
	time ~/Desktop/ants_reg.sh -i ${subj_id} -m ANTS_struct2MNI -b struct_ext.nii.gz -t $FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz
	slicesdir -p $FSLDIR/data/standard/MNI152_T1_1mm_brain ANTS_struct2MNI_Warped.nii.gz 
	for mask in "${sn_arr[@]}"; do
	# std to subj template
	antsApplyTransforms -d 3 -i ${maskdir}/${mask}_downsized.nii.gz -r struct_ext.nii.gz -o ANTS_${mask}.nii.gz --transform ANTS_struct2MNI_1InverseWarp.nii.gz --transform [ANTS_struct2MNI_0GenericAffine.mat,1]
	# binarize mask
	fslmaths ANTS_${mask} -mul struct_ext -thr 100 -bin ANTS_${mask}
	echo "$mask warping completed"
	done
	# move to file
	mkdir BG_ANTS
	mv ANTS* BG_ANTS
	fi

	### FIRST segmentation	
	if (($f == 1)); then
	echo "f) FIRST segmentation"
	flirt -in ${struct_img} -ref $FSLDIR/data/standard/MNI152_T1_1mm -o struct_reg -omat flirt_struct2MNI.mat -searchrx -180 180 -searchry -180 180
	time run_first_all -i struct_reg -s L_Caud,L_Pall,L_Puta,L_Thal,R_Caud,R_Pall,R_Puta,R_Thal -o first
	# check for errors
	cat first.logs/*.e*
	first_roi_slicesdir struct_reg.nii.gz first_all_none_firstseg.nii.gz
	# auto-extract all masks
	echo "binarize FIRST masks"
	for i in "${first_arr[@]}"; do
	echo $i
	first_utils --meshToVol -m first-${i}_first.vtk -i struct_reg.nii.gz -l 1 -o FIRST_${i}.nii.gz
	fslmaths FIRST_${i}.nii.gz -uthr 100 -bin FIRST_${i}.nii.gz
	convert_xfm -omat flirt_MNI2struct.mat -inverse flirt_struct2MNI.mat
	flirt -in FIRST_${i} -ref ${struct_img} -out FIRST_${i} -applyxfm -init flirt_MNI2struct.mat 
	fslmaths FIRST_${i}.nii.gz -thr 0.8 -bin FIRST_${i}.nii.gz
	done
	# move to file
	mkdir BG_FIRST
	mv first* FIRST* BG_FIRST
	fi

	### Freesurfer	
	if (($s == 1)); then
	echo "s) Freesurfer segmentation"
	recon-all -subjid ${subj_id} -i ${subj_id}_t1MPR.nii.gz -all
	cp -r $SUBJECTS_DIR/${subj_id}/mri/aseg.mgz .
	mri_convert aseg.mgz aseg.nii.gz
	declare -i count=0
	for i in "${first_arr[@]}"; do
		fslmaths aseg -thr "${freesurfer_label[count]}" -uthr "${freesurfer_label[count]}" -bin FREE_${i}
		((count++))
	done
	mkdir BG_Freesurfer
	mv aseg* FREE* BG_Freesurfer
	rm $SUBJECTS_DIR/${subj_id}
	fi
#######################################################################
	## run SIENAX
	if (($g == 1)); then
		echo "Running SIENAX on structural image"
		if [ ! -f "struct_reg.nii.gz" ]; then
			echo "Running pre-registration to MNI"
			flirt -in ${struct_img} -ref $FSLDIR/data/standard/MNI152_T1_1mm -o struct_reg -omat flirt_struct2MNI.mat -searchrx -180 180 -searchry -180 180
			sienax struct_reg -o SIENAX	
		else
			echo "WARNING: running SIENAX using prior registration"
			sienax struct_reg -o SIENAX #-B "-g -0.2"
		fi;
	fi;
#######################################################################
	### Sample masks	
	if (($t == 1)); then
	echo "t) Sample masks"
	declare -i count=0
	for m in "${modes[@]}"; do
	segs=""
	
	if [ -d "BG_ANTS" ]; then
	segs="${segs} ANTS,"
	echo $'Structure\r\n' > ANTS_${m}_${subj_id}.txt
	for arr in "${sn_arr[@]}"; do
	if (($tmode == 2)); then
	echo -en "Registering ${arr} (${m}) ...\r"
	flirt -in BG_ANTS/ANTS_${arr} -ref ${subj_id}_DTI -out BG_ANTS/ANTS_${arr}_DTI -applyxfm -usesqform	
	fi
		echo "$arr: " >> ANTS_${m}_${subj_id}.txt
		fslstats BG_ANTS/ANTS_${arr} -V >> ANTS_${m}_${subj_id}.txt
		fslstats ${subj_id}_${m} -k BG_ANTS/ANTS_${arr}_DTI -M -S -H 50 0 "${limits[count]}" >> ANTS_${m}_${subj_id}.txt
		echo $'\r\n' >> ANTS_${m}_${subj_id}.txt
	done
	fi

	if [ -d "BG_FIRST" ]; then
	segs="${segs} FIRST,"
	echo $'Structure\r\n' > FIRST_${m}_${subj_id}.txt
	for arr in "${first_arr[@]}"; do
	if (($tmode == 2)); then
	echo -en "Registering ${arr} (${m}) ...\r"
	flirt -in BG_FIRST/FIRST_${arr} -ref ${subj_id}_DTI -out BG_FIRST/FIRST_${arr}_DTI -applyxfm -usesqform	
	fi
		echo "$arr: " >> FIRST_${m}_${subj_id}.txt
		fslstats BG_FIRST/FIRST_${arr} -V >> FIRST_${m}_${subj_id}.txt
		fslstats ${subj_id}_${m} -k BG_FIRST/FIRST_${arr}_DTI -M -S -H 50 0 "${limits[count]}" >> FIRST_${m}_${subj_id}.txt
		echo $'\r\n' >> FIRST_${m}_${subj_id}.txt
	done	
	fi

	if [ -d "BG_Freesurfer" ]; then
	segs="${segs} Freesurfer,"
	echo $'Structure\r\n' > FREE_${m}_${subj_id}.txt
	for arr in "${first_arr[@]}"; do
	if (($tmode == 2)); then
	echo -en "Registering ${arr} (${m}) ...\r"
	flirt -in BG_Freesurfer/FREE_${arr} -ref ${subj_id}_DTI -out BG_Freesurfer/FREE_${arr}_DTI -applyxfm -usesqform	
	fi
		echo "$arr: " >> FREE_${m}_${subj_id}.txt
		fslstats BG_Freesurfer/FREE_${arr} -V >> FREE_${m}_${subj_id}.txt
		fslstats ${subj_id}_${m} -k BG_Freesurfer/FREE_${arr}_DTI -M -S -H 50 0 "${limits[count]}" >> FREE_${m}_${subj_id}.txt
		echo $'\r\n' >> FREE_${m}_${subj_id}.txt
	done
	fi
	
	if [[ -n $segs ]]; then
	segs="${segs::-1}"
	echo "Extracting $m values for${segs}"
	else
	echo "ERROR: no mask directories detected ($m)"	
	fi
	((count++))
	done
	fi
	
	### Sample QSM	
	if (($c == 1)); then

	echo $'Structure\r\n' > FIRST_QSM_${subj_id}.txt
	for arr in "${first_arr[@]}"; do
		echo "Registering ${arr} to QSM"
		flirt -in BG_FIRST/FIRST_${arr} -ref ${subj_id}_QSM -out BG_FIRST/FIRST_${arr}_QSM -applyxfm -usesqform	
		echo "$arr: " >> QSM_${m}_${subj_id}.txt
		fslstats ${subj_id}_QSM -k BG_FIRST/FIRST_${arr}_QSM -M -S -H 50 -300 300 >> FIRST_QSM_${subj_id}.txt
	echo $'\r\n' >> FIRST_QSM_${subj_id}.txt
	done
	fi

	### Extract volume using FIRST
	if (($vmode == 2)); then
		echo $'Structure\r\n' > FIRST_BGVOL_${subj_id}.txt
		declare -i count=0
		for arr in "${first_arr[@]}"; do
			echo "$arr: " >> FIRST_BGVOL_${subj_id}.txt
			fslstats BG_FIRST/first_all_none_firstseg -l "$((${freesurfer_label[count]}-1)).5" -u "$((${freesurfer_label[count]})).5" -V >> FIRST_BGVOL_${subj_id}.txt
			echo $'\r\n' >> FIRST_BGVOL_${subj_id}.txt
			((count++))
		done	
	fi
#######################################################################
	if (($z == 1)); then
		cd ../..
	else
		cd ..
	fi
done
#######################################################################
### run vertex analysis
# program compatibility with non tp later
# check if design files exist
if (($vmode == 1)); then
mkdir vertex_analysis
if (($z == 1)); then
	bvar_dir="*/TP${zmode}/BG_FIRST"
	mkdir vertex_analysis/TP${zmode}
	vertex_dir="vertex_analysis/TP${zmode}"
	design_dir="../design/DTIFU_TP${zmode}.mat"
else
	bvar_dir="*/BG_FIRST"
	vertex_dir="vertex_analysis"
	design_dir="../design/DTIFU.mat"
fi
	for arr in "${first_arr[@]}"; do
	ls -1 ${bvar_dir}/first-${arr}_first.bvars > bvar_list.txt
	num_sub=($(ls -1 ${bvar_dir}/first-${arr}_first.bvars | wc -l))
	no_sub=($(seq -w 0 $((${num_sub}-1))))
	list="bvar_list.txt"
	if (($d == 1)); then
		echo "TP${zmode} -> TP$((${zmode}-1))"
		sed "s/TP${zmode}/TP$((${zmode}-1))/g" bvar_list.txt > long_bvar.txt
		cat bvar_list.txt long_bvar.txt > bvar_cat.txt
		list="bvar_cat.txt"
		vertex_dir="vertex_analysis/longitudinal"
		design_dir="../design/DTIFU_long.mat"
	fi;
	rm ${vertex_dir}/${arr}.bvars
	concat_bvars ${vertex_dir}/${arr}.bvars $(cat $list | tr '\n' ' ')
	echo "Run first utils for $arr"
	first_utils --vertexAnalysis --usebvars -i ${vertex_dir}/${arr}.bvars -d ${design_dir} -o ${vertex_dir}/${arr}_shape --useReconNative --useRigidAlign
	if (($d == 1)); then
		cd ${vertex_dir}
		fslsplit ${arr}_shape
		no_sub_long=($(seq -w ${num_sub} $((${num_sub}*2-1))))
		count=0
		for i in "${no_sub[@]}"; do 
			echo "subtract ${i} from ${no_sub_long[count]}"
			fslmaths vol00${i} -sub vol00${no_sub_long[count]} sub${i}_diff;
			((count++))
		done
		fslmerge -t ${arr}_shape.nii.gz *_diff.nii.gz
		rm vol* sub*
		cd ../..
		design_dir="../design/DTIFU_TP${zmode}.mat"
	fi;
	randomise_parallel -i ${vertex_dir}/${arr}_shape.nii.gz -m ${vertex_dir}/${arr}_shape_mask.nii.gz -o ${vertex_dir}/${arr}_rand -d ${design_dir} -t ../design/DTIFU.con -D -T
	#fdr -i grot_vox_p_tstat1 --oneminusp -m mask -q 0.05 --othresh=thresh_grot_vox_p_tstat1
	done
fi

