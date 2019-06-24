#!/bin/bash

# call: ~/Desktop/manual_correction.sh C01 AC
# AC - green; SOS - blue

declare -a bg_arr=("L_atl_Caud" "L_atl_Pal" "L_atl_Put" "L_atl_Tha" "R_atl_Caud" "R_atl_Pal" "R_atl_Put" "R_atl_Tha")
declare -a sn_arr=("L_atl_SN" "R_atl_SN" "L_atl_RN" "R_atl_RN" "L_atl_GPe" "R_atl_GPe" "R_atl_GPe" "R_atl_GPi")

subj=$1
tp=$2
echo "Opening files for ${tp}: $subj"
AC_subj="${subj}_processed/${tp}"
SOS_subj="${subj}_processed/SOS3"

fsleyes ${AC_subj}/DTI_${tp}-${subj}_MD_ex.nii.gz ${AC_subj}/DTI_${tp}-${subj}_SWI_ex.nii.gz ${AC_subj}/L_atl_SN_warped -cm green ${AC_subj}/R_atl_SN_warped -cm green ${AC_subj}/L_atl_RN_warped -cm green ${AC_subj}/R_atl_RN_warped -cm green 

# ${AC_subj}/L_atl_Caud_warped -cm green ${AC_subj}/L_atl_Pal_warped -cm green ${AC_subj}/L_atl_Put_warped -cm green ${AC_subj}/L_atl_Tha_warped -cm green ${AC_subj}/R_atl_Caud_warped -cm green ${AC_subj}/R_atl_Pal_warped -cm green ${AC_subj}/R_atl_Put_warped -cm green ${AC_subj}/R_atl_Tha_warped -cm green 

#${SOS_subj}/DTI_SOS3-${subj}_MD_ex.nii.gz ${SOS_subj}/L_atl_Caud_warped -cm blue ${SOS_subj}/L_atl_Pal_warped -cm blue ${SOS_subj}/L_atl_Put_warped -cm blue ${SOS_subj}/L_atl_Tha_warped -cm blue ${SOS_subj}/R_atl_Caud_warped -cm blue ${SOS_subj}/R_atl_Pal_warped -cm blue ${SOS_subj}/R_atl_Put_warped -cm blue ${SOS_subj}/R_atl_Tha_warped -cm blue ${SOS_subj}/L_atl_SN_warped -cm blue ${SOS_subj}/R_atl_SN_warped -cm blue ${SOS_subj}/L_atl_RN_warped -cm blue ${SOS_subj}/R_atl_RN_warped -cm blue

# ${AC_subj}/DTI_AC3-${subj}_FA_ex.nii.gz ${AC_subj}/DTI_AC3-${subj}_MD_ex.nii.gz
