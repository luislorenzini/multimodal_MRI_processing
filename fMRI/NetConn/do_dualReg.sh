## Bash script to run dual regression Using a specific atlas (either melodic or other)
# first run the do_fmri2MNI.sh script on the uotput of fMRIprep to make sure you have fMRI files in 4mm
module load fsl/6.0.0

BIDS_DIR=/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46
derivativesdir=$BIDS_DIR/derivatives
fmriprepdir=$derivativesdir/fmriprep
DRdir=$derivativesdir/DualRegression
atlasfile=$BIDS_DIR/scripts/multimodal_MRI_processing/atlases/yeo-17-liberal_network_4mm.nii.gz ## Default is YEO networks
scratchfold=/scratch/llorenzini/insight46/derivatives # Derivative folder where to run it if it does not work on local directories 

#make outputdirectory
if [[ ! -d $DRdir ]]; then 
	mkdir $DRdir; 
else
echo "Dual Regression Output Directory is already existing, probably overwriting results" 

fi 

#selct inputs 
ls $fmriprepdir/sub*/ses*/func/*MNI4mm* >  $DRdir/fmri_inputs.txt  

# Create Design Matrix
echo "creating design matrix for `cat $DRdir/fmri_inputs.txt | wc -l` files"

sleep 2

while read file; do 
echo "1"
done < $DRdir/fmri_inputs.txt > $DRdir/design.txt

sleep 2



## Create and convert con and mat files 
echo "converting txt to mat"

Text2Vest $DRdir/design.txt $DRdir/design.mat

cat $DRdir/design.txt | head -1 > $DRdir/contrast.txt

Text2Vest $DRdir/contrast.txt $DRdir/design.con


# run the dual regression
cd $scratchfold	
if [[ -d $scratchfold ]]; then

	cp -rf $DRdir $scratchfold/; 
	echo 'Starting the dual regression';
	dual_regression $atlasfile 1 $scratchfold/DualRegression/design.mat $scratchfold/DualRegression/design.con 0 $scratchfold/DualRegression `cat $scratchfold/DualRegression/fmri_inputs.txt`
else 

	dual_regression $atlasfile 1 $DRdir/design.mat $DRdir/design.con 0 $DRdir `cat $DRdir/fmri_inputs.txt`; 
fi




