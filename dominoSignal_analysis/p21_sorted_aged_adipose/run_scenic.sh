#!/bin/bash

#SBATCH --job-name=SCENIC_adipose
#SBATCH --output=/aged_adipose/slurm.%j.o
#SBATCH --error=/aged_adipose/slurm.%j.e
#SBATCH --time=10-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --account pi-lab
#SBATCH --mail-type=start,end,fail
#SBATCH --mail-user=user@dom.edu

set -euo pipefail # Exit on error, unset variable, pipe failure
trap 'echo "Error occurred at line $LINENO while executing: $BASH_COMMAND"' ERR

module load apptainer/1.3.6

# Set up file paths
WORKING_DIR="/aged_adipose/"
DATA_DIR="${WORKING_DIR}/data/"
REF_DIR="${WORKING_DIR}/refs/"
NAME="aged_adipose"
RESULTS_DIR="${WORKING_DIR}/results/"

# Get image:
SIF_IMAGE="${WORKING_DIR}/aertslab-pyscenic-0.12.1.sif"
if [ ! -r "$SIF_IMAGE" ]; then
  echo "Missing or unreadable container: $SIF_IMAGE" >&2
  exit 1
fi

# Get loom file
LOOM_FILE="${DATA_DIR}/adipose_counts.loom"
if [ ! -f "$LOOM_FILE" ]; then
  echo "Missing loom file: $LOOM_FILE" >&2
  exit 1
fi

# Set file names
TF_REFERENCE="${REF_DIR}/allTFs_mm.txt"
TSS_REF1="${REF_DIR}/mm10_500bp_up_100bp_down.genes_vs_motifs.rankings.feather"
TSS_REF2="${REF_DIR}/mm10_10kbp_up_10kbp_down.genes_vs_motifs.rankings.feather"
MOTIF_REF="${REF_DIR}/motifs-v10-nr.mgi.tbl"

GRN_RESULT="${RESULTS_DIR}/adj_${NAME}.tsv"
REGULON_RESULT="${RESULTS_DIR}/regulons_${NAME}.csv"
AUC_RESULT="${RESULTS_DIR}/auc_${NAME}.csv"

echo "Starting SCENIC analysis"

apptainer exec "$SIF_IMAGE" pyscenic grn \
    "${LOOM_FILE}" \
    "${TF_REFERENCE}" \
    -o "$GRN_RESULT" \
    --seed 123 \
    --num_workers 8

echo "Step 1: GRN calculation complete, starting regulon calculation"

apptainer exec "$SIF_IMAGE" pyscenic ctx \
    "${GRN_RESULT}" \
    "${TSS_REF1}" \
    "${TSS_REF2}" \
    --annotations_fname "${MOTIF_REF}" \
    --expression_mtx_fname "${LOOM_FILE}" \
    --mode "dask_multiprocessing" \
    --output "${REGULON_RESULT}" \
    --num_workers 8

echo "Step 2: Regulon calculation complete, starting AUC calculation"

apptainer exec "$SIF_IMAGE" pyscenic aucell \
    "${LOOM_FILE}" \
    "${REGULON_RESULT}" \
    -o "${AUC_RESULT}"

echo "Step 3: AUC calculation complete. SCENIC analysis finished."
