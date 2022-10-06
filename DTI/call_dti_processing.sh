SCRIPTS_DIR=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46/scripts/DTI
RUN_DIR=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46/scripts/
ORIG_BIDS_DIR=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46/raw
processing_BIDS_DIR=/scratch/llorenzini/insight46_DTI/raw
OUTPUT_DIR=/scratch/llorenzini/insight46_DTI/derivatives
final_OUTPUT_DIR=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46/derivatives
orig_WORK_DIR=/scratch/llorenzini/insight46_DTI/logs
ATLAS_FILE=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46/scripts/schaeffer_100.nii.gz
session=ses-01 # Process baseline or follow-up?




# create final output directory if needed
if [ ! -d $final_OUTPUT_DIR/qsiprep ]; then
	mkdir -p $final_OUTPUT_DIR/qsiprep
	mkdir -p $final_OUTPUT_DIR/qsirecon
else
	printf "final output directory already exists\n\n"
fi

# copy dataset description json

cp $ORIG_BIDS_DIR/dataset_description.json $processing_BIDS_DIR/dataset_description.json


for subjectname in `ls -d ${ORIG_BIDS_DIR}/sub-*`; do


bidsname="`basename $subjectname`"; 
PARTICIPANT_LABEL="`echo $bidsname | cut -d '-' -f 2`"
WORK_DIR=${orig_WORK_DIR}/$PARTICIPANT_LABEL

# Make Subject Working Directory and run DTI (sleeping 1 minute)
mkdir $WORK_DIR;
sleep 1m
cd $RUN_DIR 

#nvisit=`ls $subjectname | wc -l`


mkdir $processing_BIDS_DIR/$bidsname
cp -rf $subjectname/$session $processing_BIDS_DIR/$bidsname

sbatch $SCRIPTS_DIR/dti_processing_slurm.sh $processing_BIDS_DIR $OUTPUT_DIR $PARTICIPANT_LABEL $WORK_DIR $final_OUTPUT_DIR $ATLAS_FILE $session;





#cp -rf $subjectname $processing_BIDS_DIR
#sbatch $SCRIPTS_DIR/dti_processing_slurm.sh $processing_BIDS_DIR $OUTPUT_DIR $PARTICIPANT_LABEL $WORK_DIR $final_OUTPUT_DIR   




while [[ $(ls $orig_WORK_DIR/ | wc -l) = 5 ]]; do 
sleep 10; 
done


done 

