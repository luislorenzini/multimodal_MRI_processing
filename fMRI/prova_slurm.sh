#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16000              # max memory per node
# Request 36 hours run time
#SBATCH -t 36:0:0
#SBATCH --nice=100			# be nice
#SBATCH --partition=rng-long  # rng-short is default, but use rng-long if time exceeds 7h




echo "The job number is  $SLURM_JOB_ID"

sleep 1 

echo "Moving job $SLURM_JOB_ID output to home dir"

mv slurm-${SLURM_JOB_ID}.out ~
