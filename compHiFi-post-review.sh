#!/bin/bash
set -e

# Function to display usage
usage() {
	echo ""
    echo "CompHiFi (Comprehensive HiFi Assembler) v0.2"
    echo ""
    echo "CompHiFi is a comprehensive genome assembly pipeline designed to handle High-Fidelity (HiFi) sequencing data."
    echo "It automates the entire process from data preparation, assembly, scaffolding, gap closing, to evaluation, using a variety of state-of-the-art tools."
    echo ""
    echo "Usage: compHiFi-post-review.sh --assembly <reviewed_assembly_filename>"
    echo
    echo "This script continues the remaining steps of the pipeline after manual review of the 3D-DNA assembly by Juicebox."
    echo "Please ensure that the reviewed assembly file is placed in 03.scaffolding/3d-dna."
    echo "Run this script within the original working directory."
    echo
    echo "Required parameter:"
    echo "  --assembly <filename>  The manually reviewed assembly FILENAME, not path (e.g., 3ddna.hifiasm.asm.final.review.assembly)."
    echo
    echo "Example:"
    echo "  compHiFi-post-review.sh --assembly 3ddna.hifiasm.asm.final.review.assembly"
	echo ""
    exit 1
}

# Default values
CPU=$(nproc)  # Default to all available CPUs
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Function to print messages with timestamp
log() {
    echo -e "\e[32m[$(date +'%H:%M:%S')] $1\e[0m"
}

# Define the error handler function
error_handler() {
    echo -e "\e[31m [ERROR] An error occurred, compHiFi aborted!\e[0m"
}

# Use trap to catch the ERR signal and execute the error_handler function
trap error_handler ERR

# Check if no arguments were provided
if [ $# -eq 0 ]; then
    usage
fi

# Parse arguments
REVIEWED_ASSEMBLY=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --assembly)
            REVIEWED_ASSEMBLY="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
done

# Check for required parameters
if [ -z "$REVIEWED_ASSEMBLY" ]; then
    echo -e "\e[31m [ERROR] Error: Missing required parameters!\e[0m"
    usage
fi


# clean up old results
rm -rf 04.gapClose/*
rm -rf 05.final_eval/*

cd 03.scaffolding/3d-dna
log "Proceeds to the remaining steps of the pipeline after manual review"
bash ${SCRIPT_DIR}/utils/3d-dna/run-asm-pipeline-post-review.sh -r ${REVIEWED_ASSEMBLY} 3ddna.hifiasm.asm.fa ../juicer-1.6/aligned/merged_nodups.txt


workdir=$(dirname "$(dirname "$(pwd)")")

cd ${workdir}
[ -e 03.scaffolding/scaffolding.3ddna.fa ] && rm 03.scaffolding/scaffolding.3ddna.fa
ln -s $(realpath 03.scaffolding/3d-dna/3ddna.hifiasm.asm.FINAL.fasta) 03.scaffolding/scaffolding.3ddna.fa

log "Section 3: Scaffolding completed. Results are in the 03.scaffolding directory."


# Section 4: GapClose
log "Section 4: GapClose"

# Part 1: Preparing input files...
# Combine all fa files except hifiasm.asm.fa
for file in 01.assembles/*.fa; do
    if [[ $file != *"hifiasm.asm.fa" ]]; then
        cat $file >> 04.gapClose/all_contigs.fa
    fi
done

# Part 2: Running QuarTeT for gap closing...
quartet gf -t 16 -d 03.scaffolding/scaffolding.3ddna.fa -g 04.gapClose/all_contigs.fa
mkdir -p 04.gapClose/quartet
ls quarTeT* 1> /dev/null 2>&1 && mv quarTeT* 04.gapClose/quartet
ls tmp/ 1> /dev/null 2>&1 && mv tmp/ 04.gapClose/quartet
if [ -f "04.gapClose/quartet/quarTeT.genome.filled.fasta" ]; then
    ln -s $(realpath 04.gapClose/quartet/quarTeT.genome.filled.fasta) 04.gapClose/scaffolding.3ddna.gapclosed.fa
else
    ln -s $(realpath 03.scaffolding/scaffolding.3ddna.fa) 04.gapClose/scaffolding.3ddna.gapclosed.fa
fi

log "Section 4: GapClose completed. Results are in the 04.gapClose directory."

# Section 5: Final Evaluation
log "Section 5: Final Evaluation"

# Part 1: Running quast...
quast -o 05.final_eval/quast -t 16 04.gapClose/scaffolding.3ddna.gapclosed.fa

# Part 2: Running busco...
busco -m genome -i 04.gapClose/scaffolding.3ddna.gapclosed.fa -o 05.final_eval/busco_result -l embryophyta_odb10 -c 16 --offline -f --download_path  /opt/busco_db/
ln -s $(realpath 05.final_eval/busco_result/short_summary.specific.embryophyta_odb10.busco_result.txt) 05.final_eval/busco.short_summary.txt

log "Section 5: Final Evaluation completed. Results are in the 05.final_eval directory."
log "All pipeline finished!"
log "Assembled genome in the [04.gapClose/scaffolding.3ddna.gapclosed.fa] file"
log "Evaluation results in the [02.asm_eval] and [05.final_eval] directories."


