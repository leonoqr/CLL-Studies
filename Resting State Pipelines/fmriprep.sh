#!/bin/bash

### ------------------------
# preprocess fmri data using fmriprep
# cmd prompt: ~/Desktop/rsf_analysis.sh -i pat_id <opts> 
# Author: Leon Ooi
### ------------------------

docker run -ti --rm \
-v :/fmriprep_data:ro \
-v :/fmriprep_results \
poldracklab/fmriprep \
/fmriprep_data /fmriprep_results \
N3 \
#--fslicense-file $FREESURFER_HOME/license --participant_label N3
