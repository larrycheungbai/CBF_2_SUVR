#!/bin/bash

# === Configuration ===
Out_Dir="/media/zewang/LD12T/2025_Projects/ADNI_BOLD_CBF_2_PET/Data/reg_MNI_pet_2_suvr"
Mask_Dir="$Out_Dir/Mask"

# SUVR output CSV
SUVR_CSV="$Out_Dir/SUVR_Values.csv"
echo "Sub_ID,Hippocampus,Postcentral_Gyrus,Posterior_Cingulate_Cortex,Precuneus" > "$SUVR_CSV"

start_time=$(date +%s)

#Done. 
#"$Out_Dir/135_S_5113_ADNI_F18-Florbetapir_Brain_G0__AV45_2015-04-22_15_04_"
# === Loop through each subject folder ===
for subj_dir in "$Out_Dir"/*; do
    subj_name=$(basename "$subj_dir")
    echo "[INFO] Processing $subj_name"
    cd "$subj_dir"
    
    #bet 
    #bet highres_orig.nii.gz   highres.nii.gz
    
    mkdir -p temp/3d_vols temp/3d_vols_align temp/3d_vols_mat temp/3d_vols_bet
    
    fslsplit pet_func.nii.gz temp/3d_vols/vol_
    
    #    echo "[INFO] Running FSL BET on each 3D PET volume"
    for vol in temp/3d_vols/vol_*.nii.gz; do
        fname=$(basename "$vol")
        # Apply BET. You might need to adjust -f (fractional intensity threshold) and -g (vertical gradient)
        # for optimal brain extraction on PET data.
        bet "$vol" "temp/3d_vols_bet/${fname%.nii.gz}_brain.nii.gz" -F 
    done

    for vol in temp/3d_vols_bet/*_brain.nii.gz; do #temp/3d_vols/vol_*.nii.gz; do
        fname=$(basename "$vol")
        echo "Current Registerred 3d volume $fname"
        flirt -in "$vol" -ref highres.nii.gz -out "temp/3d_vols_align/$fname" -omat "temp/3d_vols_mat/${fname%.nii.gz}.mat" -cost corratio -dof 6 -interp trilinear
    done
    echo "Volume alignment complete"
    
    
    # Merge and average to get co-registered PET
    fslmerge -t temp/pet_merged temp/3d_vols_align/vol_*.nii.gz # Or use *_brain.nii.gz, both work here
    fslmaths temp/pet_merged -Tmean CoRegistered_PET.nii.gz
    echo "Co-registered PET image created"
        
    # === Step 2: T1 to MNI Registration (affine + non-linear) ===
    echo "Running T1 to MNI registration with fnirt..."
    # First, run flirt to get the affine matrix
    flirt -in highres.nii.gz -ref standard -out T1_in_MNI_flirt.nii.gz -omat T1_in_MNI_flirt.mat -cost corratio -searchcost corratio -dof 12 -interp trilinear
                   
    # Then, run fnirt to get the non-linear warp field
    fnirt --in=highres.nii.gz --aff=T1_in_MNI_flirt.mat --cout=T1_to_MNI_non_linear_warp --config=T1_2_MNI152_2mm
    
    #Create the inverse non-linear warp for back-transformations
    invwarp -w T1_to_MNI_non_linear_warp -o MNI_to_T1_non_linear_warp -r highres.nii.gz     
                    
    # === Step 3: Normalization and PVC using the warped images ===
    echo "Normalizing and applying partial volume correction..."
    # Normalize PET by mean cerebellum_pons signal in subject space
    applywarp --ref=highres.nii.gz --in="$Mask_Dir/cerebellum_pons_mask_binary.nii.gz" \
              --warp=MNI_to_T1_non_linear_warp \
              --out=cerebellum_pons_mask_sub_space.nii.gz
            
    fslmaths CoRegistered_PET.nii.gz -mul cerebellum_pons_mask_sub_space.nii.gz pet_only_cerebellum_pons_sub_space.nii.gz
    mean_ref=$(fslstats pet_only_cerebellum_pons_sub_space.nii.gz -M)
    fslmaths CoRegistered_PET.nii.gz -div $mean_ref normalized_pet_by_cerebellum_and_pons_sub_space.nii.gz

    # Now, apply the non-linear warp to the normalized PET image
    applywarp --ref=standard --in=normalized_pet_by_cerebellum_and_pons_sub_space.nii.gz \
              --warp=T1_to_MNI_non_linear_warp \
              --out=normalized_pet_in_MNI_Space_warped.nii.gz
    
    # Create 4D Talairach mask
    pvc_make4d -i "$Mask_Dir/talairach_label_all.nii.gz" -o talairach-4DMASK.nii.gz
    echo "Create 4D Talairach mask complete"

    # Run PETPVC with IY model
    petpvc -i normalized_pet_in_MNI_Space_warped.nii.gz -m talairach-4DMASK.nii.gz \
           -o normalized_talairach_pet_pvc_image.nii.gz --pvc IY -x 7.67 -y 7.5 -z 7.5

    # Back-transform PVC PET to subject space
    applywarp --ref=highres.nii.gz --in=normalized_talairach_pet_pvc_image.nii.gz \
              --warp=MNI_to_T1_non_linear_warp \
              --out=normalized_talairach_pet_pvc_sub_space.nii.gz
    echo "Back-transformation of PVC PET to subject space complete"
    echo "[DONE] $subj_name processed"
done

echo "**** SUVR Calculation Completed *******"
echo "Results saved to: $SUVR_CSV"
