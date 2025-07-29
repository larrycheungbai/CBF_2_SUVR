#!/usr/bin/env bash

##########################################################################################################################
## SCRIPT TO DO IMAGE REGISTRATION
## parameters are passed from 0_preprocess.sh
##
## !!!!!*****ALWAYS CHECK YOUR REGISTRATIONS*****!!!!!
##
##
## Written by the Underpants Gnomes (a.k.a Clare Kelly, Zarrar Shehzad, Maarten Mennes & Michael Milham)
## for more information see www.nitrc.org/projects/fcon_1000
##
##########################################################################################################################
sub=$1

mkdir /media/zewang/12TB/TBI/reg/${sub}
## copy T1 structure
cp /media/Big4/share_vincent/old_processing/${sub}/v1/T1w_acpc_dc_restore_brain.nii.gz /media/zewang/12TB/TBI/reg/${sub}/highres.nii.gz
### copy standard
cp /home/zewang/fsl/data/standard/MNI152_T1_2mm_Brain.nii.gz /media/zewang/12TB/TBI/reg/${sub}/standard.nii.gz
### copy PET
cp /media/Big4/share_vincent/old_processing/${sub}/v1/PET_file_name.nii.gz /media/zewang/12TB/TBI/reg/${sub}/example_func.nii.gz
### copy brain gray matter mask
#cp /media/zewang/12TB/Vincent/DAscripts/HarvardOxford-cort-maxprob-thr25-2mm.nii.gz /media/zewang/12TB/TBI/reg/${sub}/brain_mask_cor.nii.gz
#cp /home/zewang/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr25-2mm.nii.gz /media/zewang/12TB/TBI/reg/${sub}/brain_mask_sub.nii.gz
#cp /home/zewang/Downloads/Schaefer2018_400Parcels_7Networks_order_FSLMNI152_2mm.nii.gz /media/zewang/12TB/TBI/reg/${sub}/brain_mask_sch.nii.gz

cd /media/zewang/12TB/TBI/reg/${sub}/

## 1. function image to structure
flirt -ref highres -in example_func -out example_func2highres -omat example_func2highres.mat -cost corratio -dof 6 -interp trilinear
# Create mat file for conversion from subject's anatomical to functional
convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat

## 2. T1->STANDARD
flirt -ref standard -in highres -out highres2standard -omat highres2standard.mat -cost corratio -searchcost corratio -dof 12 -interp trilinear
## Create mat file for conversion from standard to high res
convert_xfm -inverse -omat standard2highres.mat highres2standard.mat


## 3. FUNC->STANDARD
fnirt --in=highres --aff=highres2standard.mat --cout=my_nonlinear_transf --config=T1_2_MNI152_2mm
applywarp --ref=standard --in=example_func --warp=my_nonlinear_transf --premat=example_func2highres.mat --out=example_func2standard
invwarp -w my_nonlinear_transf -o standard2highres_warp -r highres
#applywarp --ref=example_func --in=/media/zewang/12TB/Vincent/DAscripts/HarvardOxford-cort-maxprob-thr25-2mm.nii.gz --warp=standard2highres_warp --postmat=highres2example_func.mat --out=cor2example_func
#applywarp --ref=example_func --in=/home/zewang/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr25-2mm.nii.gz --warp=standard2highres_warp --postmat=highres2example_func.mat --out=sub2example_func
#applywarp --ref=example_func --in=/home/zewang/Downloads/Schaefer2018_400Parcels_7Networks_order_FSLMNI152_2mm.nii.gz --warp=standard2highres_warp --postmat=highres2example_func.mat --out=sch2example_func


