#!/bin/bash

### ------------------------
# Version: 26.06.19
# Extract motion parameters for all subjects
# cmd prompt: ~/Desktop/mcflirt_all.sh ../Study_subjects.txt
# Author: Leon Ooi
### ------------------------

list=('*')
for filename in $list; do
	printf "$filename\n"
	cd $filename
	mcflirt -in ${filename}_rsfmri -plots
	cd ..
done
