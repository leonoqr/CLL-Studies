#!/bin/bash
### ------------------------
# Version: 26.06.19
# Run dual regression and other custom analyses after ICA
# cmd prompt: ~/Desktop/network_fsl.sh <opts> 
# eg. Run dual regression in specified ICA directory and design files
# ~/Desktop/network_fsl.sh -i sleep.ica.25 -c sleep_design -d
# Author: Leon Ooi
### ------------------------

if [ $# -eq 0 ]; then 
	echo "No arguments supplied";
	exit 1
fi
i="0"
t="0"
c="0"
d="0"
n="0"
e="0"
r="0"
z="0"

while getopts ":i:t:c:dn:e:rz:" opt; do

	case $opt in
	i) i="1";ica_file=$OPTARG;;
	t) t="1"; base_name=$OPTARG;;
	d) d="1";;
	c) c="1"; base_name=$OPTARG; design_name="../design/design_$OPTARG.mat"; contrast_name="../design/contrast_$OPTARG.con";;
	n) n="1";nets=($(cat $OPTARG));echo "${#nets[*]} networks(s)";;
	e) e="1"; dr_file=$OPTARG;;
	r) r="1";;
	z) z="1";dr_file=$OPTARG;;

	\?)
	echo "invalid operation: -$OPTARG" >&2
	echo "options: 	-d run dual regression"
	echo "		-e extract networks"
	echo "		-r run randomise"
	echo "		-z extract Z scores"
	exit 1;;
	
	:)
	echo "option -$OPTARG requires an argument"
	echo "options: 	-i specify ICA file"
	echo "options: 	-t supply design/contrast text files"
	echo "options:	-d specify ICA file"
	echo "options: 	-c supply design/contrast files"
	echo "options:	-n supply networks analysed"
	echo "options:	-e specify dr file"
	echo "options:	-z specify dr file"
	exit 1;;

	esac
done

###################################################
# Convert text files to design and contrast files for GLM
if (($t == 1)); then
	echo "Convert txt to design and contrast files"
	Text2Vest ../design/design_$base_name.txt ../design/design_$base_name.mat
	Text2Vest ../design/contrast_$base_name.txt ../design/contrast_$base_name.con
fi;
###################################################
# Run dual regression
if (($d == 1)); then
	echo "Running dual regression"
	
	# Edit here for different cohort
	echo "Generating list of subjects"
	echo $(ls -1 *-P/func_filtered.nii.gz| wc -l)" subjects files with func_filtered"
	rm dr_subjects.txt
	ls -1 *-P/func_filtered.nii.gz >> dr_subjects.txt
	echo "Running dual regression"
	# check if ica file and design files exist	
	if (($i == 0)); then
		echo "ICA file not specified! Exiting program."
		exit 1
	fi;
	if (($c == 0)); then
		echo "Design and contrast file missing! Exiting program."
		exit 1
	fi;

	# run dual regression using specified parameters
	dual_regression ${ica_file}/melodic_selected 1 ../design/${design_name} ../design/${contrast_name} 5000 ${ica_file}/dr.${base_name} $(<dr_subjects.txt)
	
	### Additional processing - REMOVED
	## FDR correction	
	#fdr -i dr_stage3_ic0007_tfce_corrp_tstat1 --oneminusp -m /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask -q 0.05 -a FDR_ic0007_tstat1
	## Cluster filtering
	#cluster -i FDR_ic0007_tstat1 -t 0.95 --connectivity=50 --othresh=FDR_thresh_ic0007_tstat1
	#fslmaths -dt int cluster_ic0007_tstat2 -thr 4 -uthr 9 -mas /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask cluster

fi;
###################################################
# Extract networks from dual regression
if (($e==1)); then
	echo "Extracting networks for analysis"
	# check if networks specified	
	if (($n == 0)); then
		echo "Network file missing! Exiting program."
		exit 1
	fi;
	cd $dr_file

	# generate subjects to iterate over
	no_subs=$(ls -1 dr_stage2_subject*_Z.nii.gz | wc -l)
	subs=($(seq -w 0 $(($no_subs-1))))
	
	# split subjects and merge networks	
	count=1
	for y in "${nets[@]}"; do
		network=${y::-1}		
		echo "Network ${network} ----- $count/${#nets[@]}"
		for x in "${subs[@]}"; do 
			fslroi dr_stage2_subject000${x}.nii.gz dr_network${network}_sub00${x} ${network} 1
		done
		fslmerge -t dr_network${network}_4d dr_network${network}_sub00*
		rm dr_network${network}_sub00*
		((count++))
	done
	# move to new file
	mkdir ../extracted_networks
	mv dr_network* ../extracted_networks
	cd ../..
fi;
###################################################
# run randomise for extracted subset of networks
if (($r==1)); then
	echo "Running randomise"
	# check if ica file, networks and design files exist
	if (($i == 0)); then
		echo "ICA file not specified! Exiting program."
		exit 1
	fi;
	if (($n == 0)); then
		echo "Network file missing! Exiting program."
		exit 1
	fi;
	if (($c == 0)); then
		echo "Design and contrast file missing! Exiting program."
		exit 1
	fi;

	# create new folder to run randomise in  
	mkdir $ica_file/randomise.${base_name}
	cd $ica_file/randomise.${base_name}

	# run randomise
	echo "Running randomise for ${#nets[@]} networks"
	for y in "${nets[@]}"; do
		network=${y::-1}
		echo "network ${network}"
		randomise_parallel -i ../extracted_networks/dr_network${network}_4d.nii.gz -o network${network} -d ../../../design/${design_name} -t ../../../design/${contrast_name} -n 5000 -m /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask -T
	done

	cd ../..

fi;
###################################################
# extract z scores for linear regression
if (($z==1)); then
	echo "Extracting z scores"
	# check if network files exist	
	if (($n == 0)); then
		echo "Network file missing! Exiting program."
		exit 1
	fi;
	
	# create masks for networks of interest	
	cd ${dr_file}
	echo "Creating masks"
	fslsplit ../melodic_selected melodic_split
	for x in "${nets[@]}"; do
		fslmaths melodic_split000${x::-1} -thr 2.5 -bin network00${x::-1}_mask
	done
	rm melodic_split*

	# extract parameters
	echo "Extracting parameters"
	mkdir Z_scores
	declare -a subs=($(ls -1 dr_stage2_subject00???_Z.nii.gz))
	for y in "${subs[@]}";do
		fslsplit $y temp
		for x in "${nets[@]}"; do
			fslmeants -i temp000${x::-1} -m network00${x::-1}_mask >> Z_scores/${y::-7}.txt
		done
		rm temp*
	done
fi;
