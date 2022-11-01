#!/bin/bash
#SBATCH --job-name=qsiprep
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=32000              # max memory per node
# Request 36 hours run time
#SBATCH -t 36:0:0
#SBATCH --partition=rng-long  # rng-short is default, but use rng-long if time exceeds 7h
#SBATCH --nice=1000			# be nice


module load mrtrix3/20181014
module load ants/2.3.5
module load fsl/6.0.4

### SETTINGS ##
QSIPREP=/store/singularity_images/qsiprep-0.15.1.sif
RECON_SPEC=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46/scripts/DTI/dhollander_msmt_gqi.json
BIDS_DIR=$1
OUTPUT_DIR=$2
PARTICIPANT_LABEL=$3 # participant label (without 'sub-')
WORK_DIR=$4 #working directory
FS_LICENSE=/opt/amc/freesurfer-7.1.1/license.txt
final_OUTPUT_DIR=$5
session=$7

# how to
if [ $# -lt 5 ]; then
	printf "\nHOW TO USE:\n

- bids_folder must contain a BIDS-valid dataset (with sub-XXX at the top level)
- output will be saved in output_folder/qsiprep/sub*
- define participant_label without 'sub-'
- working_directory is where temporary files live, make sure you have writing permissions and no space limits 
- final output directory: where to put the data once processing is done
- atlas_file: [optional] brain parcellation in T1w space\n\n"
	exit
elif [ $# -eq 5 ]; then
	printf "\nno atlas_file is provided\n\n"
elif [ $# -gt 5 ]; then
	ATLAS_FILE=$6 # ATLAS IN MNI SPACE
	ATLAS_NAME=$(basename $ATLAS_FILE)
	ATLAS_NAME="${ATLAS_NAME%.*}"
	ATLAS_NAME="${ATLAS_NAME%.*}"
	printf "\nusing atlas: ${ATLAS_NAME}\n\n"
fi



# create output directory if needed
if [ ! -d $OUTPUT_DIR ]; then
	mkdir -p $OUTPUT_DIR
	mkdir -p $OUTPUT_DIR/qsiprep
	mkdir -p $OUTPUT_DIR/qsirecon
else
	printf "output directory already exists\n\n"
fi

# create working directory if needed
if [ ! -d $WORK_DIR ]; then
	mkdir -p $WORK_DIR
else
	printf "working directory already exists\n\n"
fi


# run qsiprep if not previously done   ### REMEMBER ACQUISITION TYPE (ACQ MULTISHELL)
if [ -f "${final_OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}/$session/dwi/sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_dwi.nii.gz" ]; then

	printf "qsiprep already done for sub-${PARTICIPANT_LABEL} from ${BIDS_DIR}\n\n"
	

	# copy for further processing
	cp -r ${final_OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL} $OUTPUT_DIR/qsiprep/;
	cp -r ${final_OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL} $OUTPUT_DIR/qsirecon/;




else	
	rm -rf ${WORK_DIR}/* # empty working directory (avoids overlaps with previous executions)	
	cp $FS_LICENSE $WORK_DIR		
	printf "starting qsiprep for sub-${PARTICIPANT_LABEL} from ${BIDS_DIR}\n\n"	
	nice singularity run --cleanenv -B $BIDS_DIR -B $OUTPUT_DIR -B $WORK_DIR -B $RECON_SPEC -B `dirname $FS_LICENSE` $QSIPREP $BIDS_DIR $OUTPUT_DIR participant \
	--skip-bids-validation \
	--participant-label $PARTICIPANT_LABEL \
	--output-space {T1w,template} \
	--template MNI152NLin2009cAsym \
	--output-resolution 2 \
	--hmc_model eddy \
	--use-syn-sdc \
	--force-syn \
	--recon-spec $RECON_SPEC \
	--fs-license-file $FS_LICENSE \
	--work-dir ${WORK_DIR} 	


fi



# obtain 5tt and gmwmi files
if [[ -f "${final_OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/$session/dwi/sub-${PARTICIPANT_LABEL}_desc-gmwmSeed_coreg.mif" ]]; then

	printf "5tt and gmwmi files already obtained for sub-${PARTICIPANT_LABEL} from ${BIDS_DIR}\n\n"
else
	# move to the recon folder
	cd ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/$session/dwi 
	# get 5tt file	
	printf "computing 5tt file for sub-${PARTICIPANT_LABEL} from ${BIDS_DIR}\n\n"

	5ttgen fsl ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}/anat/sub-${PARTICIPANT_LABEL}_desc-preproc_T1w.nii.gz sub-${PARTICIPANT_LABEL}_desc-5tt_nocoreg.nii.gz 
		
	mrconvert sub-${PARTICIPANT_LABEL}_desc-5tt_nocoreg.nii.gz sub-${PARTICIPANT_LABEL}_desc-5tt_nocoreg_lps.nii.gz -strides -1,-2,3 ## GET IT IN LPS+ SPACE
	
	printf "Registering 5tt to dwi image \n\n"	
	nice antsApplyTransforms -d 3 -e 3 -i sub-${PARTICIPANT_LABEL}_desc-5tt_nocoreg_lps.nii.gz -r ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}/$session/dwi/sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_dwi.nii.gz -o sub-${PARTICIPANT_LABEL}_desc-5tt_coreg.nii.gz -t ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}/anat/sub-${PARTICIPANT_LABEL}_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5 --float # PUT IT IN 2 MM
	
	mrconvert sub-${PARTICIPANT_LABEL}_desc-5tt_coreg.nii.gz sub-${PARTICIPANT_LABEL}_desc-5tt_coreg.mif
	5tt2gmwmi sub-${PARTICIPANT_LABEL}_desc-5tt_coreg.mif sub-${PARTICIPANT_LABEL}_desc-gmwmSeed_coreg.mif


	
fi


# do tractography if not already done
if [[ -f "${final_OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/${session}/dwi/sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck" ]]; then
	printf "tractography already done for sub-${PARTICIPANT_LABEL} from ${BIDS_DIR}\n\n"
else
	cd ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/${session}/dwi  	
	printf "starting tractography for sub-${PARTICIPANT_LABEL} from ${BIDS_DIR}\n\n"
	# tckgen	
	nice tckgen -act sub-${PARTICIPANT_LABEL}_desc-5tt_coreg.nii.gz -backtrack -nthreads 8 -select 10000000 -maxlength 250 -cutoff 0.07 \
	-seed_gmwmi sub-${PARTICIPANT_LABEL}_desc-gmwmSeed_coreg.mif \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-wmFODmtnormed_msmtcsd.mif.gz \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck
 	
	# generate tck file with less streamlines (for visualization purposes)
	nice tckedit sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck \
	-number 200k sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_200_ifod2.tck
	

	# sift2 filtering
	nice tcksift2 -act sub-${PARTICIPANT_LABEL}_desc-5tt_coreg.mif \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-wmFODmtnormed_msmtcsd.mif.gz \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-siftweights_ifod2.csv 
fi






if [ ! -z ${ATLAS_FILE+x} ]; then

	# bring atlas_file in qsiprep-T1w space if not already done
	if [ -f "${final_OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/${session}/dwi/${ATLAS_NAME}_t1space.nii.gz" ]; then
		printf "${ATLAS_NAME} already brought in qsiprep-T1w space for sub-${PARTICIPANT_LABEL}\n\n"
	else	
	cd ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/${session}/dwi  	
	native_t1=${BIDS_DIR}/sub-${PARTICIPANT_LABEL}/${session}/anat/sub-${PARTICIPANT_LABEL}_${session}_T1w.nii.gz
	qsiprep_t1=${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}/${session}/dwi/sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_dwi.nii.gz
	mni2native=${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}/anat/sub-${PARTICIPANT_LABEL}_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5
		

	# first register atlas to original T1
	nice antsApplyTransforms -d 3 \
	-i $ATLAS_FILE \
	-r $qsiprep_t1 \
	-o ${ATLAS_NAME}_t1space.nii.gz \
	-n NearestNeighbor \
	-t $mni2native

	fi

	# build structural connectome if not already done
	if [ -f "${final_OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/${session}/dwi/${ATLAS_NAME%%.*}_sift2.csv" ]; then
		printf "structural connectivity matrix already computed for atlas: ${ATLAS_NAME}\n\n"
	else	
	cd ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}/${session}/dwi 			
	printf "computing structural connectivity matrix for atlas: ${ATLAS_NAME}\n\n"
			
	# compute matrix (edges are sum of streamline weights)
	nice tck2connectome -symmetric -zero_diagonal sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck ${ATLAS_NAME}_t1space.nii.gz ${ATLAS_NAME%%.*}_sift2.csv -tck_weights_in sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-siftweights_ifod2.csv -out_assignment ${ATLAS_NAME%%.*}_assignment_sift2.csv
			
	# compute matrix (edges are mean streamline length)
	nice tck2connectome -symmetric -zero_diagonal sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck ${ATLAS_NAME}_t1space.nii.gz ${ATLAS_NAME%%.*}_length.csv -scale_length -stat_edge mean

	# compute matrix (edges are mean GFA)
	mrconvert sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-gfa_gqiscalar.nii.gz sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-gfa_gqiscalar.mif.gz		
			
	nice tcksample \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-gfa_gqiscalar.mif.gz \
	sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-meanGFAweights.csv \
	-stat_tck mean

	nice tck2connectome -symmetric -zero_diagonal sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-tracks_10M_ifod2.tck ${ATLAS_NAME}_t1space.nii.gz ${ATLAS_NAME%%.*}_GFA.csv -scale_file sub-${PARTICIPANT_LABEL}_${session}_acq-multishell_space-T1w_desc-preproc_desc-meanGFAweights.csv -stat_edge mean

	fi

fi	

if [[ -d ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL} ]]; then 
rsync -avu --progress --ignore-existing ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL} $final_OUTPUT_DIR/qsiprep/
rsync -avu --progress --ignore-existing ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL} $final_OUTPUT_DIR/qsirecon/
fi 

if [[ -f ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}.html ]]; then

cp -rf ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}.html $final_OUTPUT_DIR/qsiprep/;

fi

if [[ -f ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}.html ]]; then

cp -rf ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}.html $final_OUTPUT_DIR/qsirecon/;

fi

rm -rf ${WORK_DIR}
rm -rf ${OUTPUT_DIR}/qsiprep/sub-${PARTICIPANT_LABEL}*
rm -rf ${OUTPUT_DIR}/qsirecon/sub-${PARTICIPANT_LABEL}*
rm -rf ${BIDS_DIR}/sub-${PARTICIPANT_LABEL}


