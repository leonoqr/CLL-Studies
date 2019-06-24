#!/bin/bash

### ------------------------
# Version: 26.06.19
# Extract motion parameters for all subjects
# cmd prompt: ~/Desktop/mcflirt_all.sh ../Study_subjects.txt
# Author: Leon Ooi
### ------------------------

list=($(cat $1))
echo "${#list[*]} subject(s)"

for x in "${list[@]}"; do
	filename=${x::-1}
	echo $filename
	cd $filename
	mcflirt -in ${filename}_rsfmri -plots
	rm ${filename}_rsfmri_mcf.nii.gz
	cd ..
done
