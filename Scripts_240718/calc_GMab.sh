#!/bin/bash

t="0"
d="0"

while getopts ":t:d:" opt; do

	case $opt in
	t) t=1;IFS=$'\n'; a=($(cat $OPTARG)); echo "${#a[*]} subjects";;
	d) d=1;di=$OPTARG;;

	*)
	echo "No argument detected"
	exit 1;;

	esac
done

## generate GMab map
if (($t==1));then
	for x in "${a[@]}"; do
		subj="v40_${x::-1}_TrioTim_mprage"
		echo $subj
		fslmaths label/label_$subj -thr 5 -uthr 12 -bin temp
		fslmaths temp -mul CSF/csf_$subj GMab/gmab_$subj
	done
	rm temp.nii.gz
fi

## diplay
if (($d==1));then
	subj="v40_${di}_TrioTim_mprage"
	fsleyes ../MPR_3T-${di} csf/csf_${subj} label/label_${subj} GMab/gmab_${subj} -cm green
fi
