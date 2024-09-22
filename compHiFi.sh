#!/bin/bash
set -e

# Function to display usage
usage() {
    echo "CompHiFi (Comprehensive HiFi Assembler) v0.2"
    echo ""
    echo "CompHiFi is a comprehensive genome assembly pipeline designed to handle High-Fidelity (HiFi) sequencing data."
    echo "It automates the entire process from data preparation, assembly, scaffolding, gap closing, to evaluation, using a variety of state-of-the-art tools."
    echo ""
    echo "Usage: bash genome_assembly_pipeline.sh --hifi <HiFi_reads> --hic1 <Hi-C_reads1> --hic2 <Hi-C_reads2> --genomeSize <genome_size> [--prefix <prefix>] [--cpu <num_cpus>] [--review]"
    echo ""
    echo "Required parameters:"
    echo "  --hifi        HiFi reads in FASTA format (comma-separated for multiple files)"
    echo "  --hic1        Hi-C reads (R1) in FASTQ format"
    echo "  --hic2        Hi-C reads (R2) in FASTQ format"
    echo "  --genomeSize  Estimated genome size"
    echo ""
    echo "Optional parameters:"
    echo "  --prefix      Prefix for output files (default: 'specie')"
    echo "  --cpu         Number of CPUs to use (default: all available CPUs)"
    echo "  --review      Enable review mode, pause pipeline for manual review with Juicebox."
    exit 1
}

# Default values
PREFIX="specie"
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
HIFI=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hifi)
            shift
            for FILE in $1; do
                HIFI="$HIFI $(realpath "$FILE")"
            done
            ;;
        --hic1) HIC1=$(realpath "$2"); shift ;;
        --hic2) HIC2=$(realpath "$2"); shift ;;
        --prefix) PREFIX="$2"; shift ;;
        --cpu) CPU="$2"; shift ;;
        --genomeSize) GENOMESIZE="$2"; shift ;;
        --review) REVIEW=1 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
	done

# Check for required parameters
if [ -z "$HIFI" ] || [ -z "$HIC1" ] || [ -z "$HIC2" ] || [ -z "$GENOMESIZE" ]; then
    echo -e "\e[31m [ERROR] Error: Missing required parameters!\e[0m"
    usage
fi


# Check for required dependencies
REQUIRED_TOOLS=(hifiasm verkko canu nextDenovo flye quast seqkit quartet busco merqury)
for TOOL in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $TOOL &> /dev/null; then
        echo -e "\e[31m [ERROR] Error: $TOOL is not installed!\e[0m"
        exit 1
    fi
done

# Create output directories
mkdir -p 01.assembles
mkdir -p 02.asm_eval
mkdir -p 03.scaffolding
mkdir -p 04.gapClose
mkdir -p 05.final_eval

# Section 1: Assembly
log "Section 1: Assembly"

# Part 1: hifiasm
log "Part 1: Running hifiasm..."
hifiasm -o hifiasm.asm -t ${CPU} ${HIFI}
mkdir -p 01.assembles/hifiasm.asm
mv hifiasm.asm* 01.assembles/hifiasm.asm
awk '/^S/{print ">"$2;print $3}' 01.assembles/hifiasm.asm/hifiasm.asm.bp.p_ctg.gfa > 01.assembles/hifiasm.asm/hifiasm.asm.fa
ln -s $(realpath 01.assembles/hifiasm.asm/hifiasm.asm.fa) 01.assembles/hifiasm.asm.fa

# Part 2: verkko
log "Part 2: Running verkko..."
verkko -d verkko.asm --hifi ${HIFI} --no-correction
mv verkko.asm 01.assembles/
ln -s $(realpath 01.assembles/verkko.asm/assembly.fasta) 01.assembles/verkko.asm.fa

# Part 3: canu
log "Part 3: Running canu..."
canu -p canu.asm -d bs_canu genomeSize=${GENOMESIZE} -pacbio-hifi ${HIFI} useGrid=false
mv bs_canu 01.assembles/
ln -s $(realpath 01.assembles/bs_canu/canu.asm.contigs.fasta) 01.assembles/canu.asm.fa

# Part 4: flye
log "Part 4: Running flye..."
flye --pacbio-hifi ${HIFI} --out-dir flye.asm --genome-size ${GENOMESIZE} -t ${CPU}
mv flye.asm 01.assembles/
ln -s $(realpath 01.assembles/flye.asm/assembly.fasta) 01.assembles/flye.asm.fa

# Part 5: nextdenovo
log "Part 5: Running nextdenovo..."

# Create input.fofn with HiFi files
echo "${HIFI}" | tr ' ' '\n' > input.fofn

# Copy and update nextdenovo.cfg
NEXTDENOVO_CFG=$(realpath $(dirname $(realpath $0))/utils/nextdenovo/nextdenovo.cfg)
cp ${NEXTDENOVO_CFG} ./nextdenovo.cfg
sed -i "s/genome_size = .*/genome_size = ${GENOMESIZE}/" nextdenovo.cfg

# Run nextdenovo
nextDenovo nextdenovo.cfg
mv 01_rundir 01.assembles/nextdenovo.asm
mv input.fofn 01.assembles/nextdenovo.asm/
mv nextdenovo.cfg 01.assembles/nextdenovo.asm/
mv *info 01.assembles/nextdenovo.asm/
ln -s $(realpath 01.assembles/nextdenovo.asm/03.ctg_graph/nd.asm.fasta) 01.assembles/nextdenovo.asm.fa

log "Section 1: Assembly completed. All results are in the 01.assembles directory."

# Section 2: Evaluation
log "Section 2: Evaluation"

# Part 1: Running quast...
quast -o 02.asm_eval -t ${CPU} 01.assembles/*.fa

log "Section 2: Evaluation completed. Results are in the 02.asm_eval directory."

# Section 3: Scaffolding
log "Section 3: Scaffolding"

# Part 1: Running Juicer...

workdir=$(pwd)
cp -r ${SCRIPT_DIR}/utils/juicer-1.6 03.scaffolding/


cd 03.scaffolding/juicer-1.6


JUICER_DIR=$(pwd)

ln -s ${workdir}/01.assembles/hifiasm.asm.fa .


python ${JUICER_DIR}/misc/generate_site_positions.py DpnII genome hifiasm.asm.fa
awk 'BEGIN{OFS="\t"}{print $1, $NF}' genome_DpnII.txt > genome.chrom.size

# Create fastq directory and link files
mkdir fastq
ln -s ${HIC1} ./fastq/hic.HIC_R1.fastq.gz
ln -s ${HIC2} ./fastq/hic.HIC_R2.fastq.gz


seqkit seq -w 80 hifiasm.asm.fa > 3ddna.hifiasm.asm.fa
bwa index 3ddna.hifiasm.asm.fa


# Run Juicer script
bash ${JUICER_DIR}/CPU/juicer.sh -g bs -d ${JUICER_DIR} -D ${JUICER_DIR}/CPU -z 3ddna.hifiasm.asm.fa -y genome_DpnII.txt -p genome.chrom.size -s DpnII -t ${CPU}


# Part 2: Running 3d-dna...
bash ${SCRIPT_DIR}/utils/3d-dna/run-asm-pipeline.sh -r 0 3ddna.hifiasm.asm.fa aligned/merged_nodups.txt

[ -d "${workdir}/03.scaffolding/3d-dna" ] && rm -rf "${workdir}/03.scaffolding/3d-dna"
mkdir ${workdir}/03.scaffolding/3d-dna
mv 3ddna.hifiasm.asm* ${workdir}/03.scaffolding/3d-dna

cd ${workdir}/03.scaffolding/3d-dna

if [[ "$REVIEW" -eq 1 ]]; then
    log "Review mode is enabled. Please use Juicebox to manually check the assembly before proceeding."
    log "The script has stopped at this point to allow you to review the assembly generated by run-asm-pipeline.sh."
    log "Once the assembly is verified, you can continue with [compHiFi-post-review.sh] to complete the remaining steps of the pipeline."
    exit 0
fi

bash ${SCRIPT_DIR}/utils/3d-dna/run-asm-pipeline-post-review.sh -r 3ddna.hifiasm.asm.FINAL.assembly 3ddna.hifiasm.asm.fa ../juicer-1.6/aligned/merged_nodups.txt

# Create a symbolic link to the final fasta file

cd ${workdir}
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


