#!/bin/bash

# Function to display usage
usage() {
    echo "CompHiFi (Comprehensive HiFi Assembler) v0.1"
    echo ""
    echo "CompHiFi is a comprehensive genome assembly pipeline designed to handle High-Fidelity (HiFi) sequencing data."
    echo "It automates the entire process from data preparation, assembly, scaffolding, gap closing, to evaluation, using a variety of state-of-the-art tools."
    echo ""
    echo "Usage: bash genome_assembly_pipeline.sh --hifi <HiFi_reads> --hic1 <Hi-C_reads1> --hic2 <Hi-C_reads2> --genomeSize <genome_size> [--prefix <prefix>] [--cpu <num_cpus>]"
    echo ""
    echo "Required parameters:"
    echo "  --hifi        HiFi reads in FASTA format (comma-separated for multiple files)"
    echo "  --hic1        Hi-C reads (R1) in FASTQ format"
    echo "  --hic2        Hi-C reads (R2) in FASTQ format"
    echo "  --genomeSize  Estimated genome size"
    echo ""
    echo "Optional parameters:"
    echo "  --prefix      Prefix for output files (default: 'result')"
    echo "  --cpu         Number of CPUs to use (default: all available CPUs)"
    exit 1
}

# Default values
PREFIX="specie"
CPU=$(nproc)  # Default to all available CPUs


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
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
	done

# Check for required parameters
if [ -z "$HIFI" ] || [ -z "$HIC1" ] || [ -z "$HIC2" ] || [ -z "$GENOMESIZE" ]; then
    log "Error: Missing required parameters."
    usage
fi

# Function to print messages with timestamp
log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Check for required dependencies
REQUIRED_TOOLS=(hifiasm verkko canu nextdenovo flye quast seqkit cd-hit quartet busco merqury)
for TOOL in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $TOOL &> /dev/null; then
        log "Error: $TOOL is not installed."
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
hifiasm -o hifiasm.asm --h1 ${HIC1} --h2 ${HIC2} -t ${CPU} ${HIFI}
mv hifiasm.asm 01.assembles/
awk '/^S/{print ">"$2;print $3}' hifiasm.asm.bp.p_ctg.gfa > 01.assembles/hifiasm.asm.fa
ln -s $(realpath 01.assembles/hifiasm.asm.fa) 01.assembles/hifiasm.asm.fa

# Part 2: verkko
log "Part 2: Running verkko..."
verkko -d verkko.asm --hifi ${HIFI} --hic1 ${HIC1} --hic2 ${HIC2}
ln -s $(realpath verkko.asm/assembly.fasta) 01.assembles/verkko.asm.fa

# Part 3: canu
log "Part 3: Running canu..."
canu -p canu.asm -d bs_canu genomeSize=${GENOMESIZE} -pacbio-hifi ${HIFI}
ln -s $(realpath bs_canu/${PREFIX}.contigs.fasta) 01.assembles/canu.asm.fa

# Part 4: flye
log "Part 4: Running flye..."
flye --pacbio-hifi ${HIFI} --out-dir flye.asm --genome-size ${GENOMESIZE} -t ${CPU}
ln -s $(realpath flye.asm/assembly.fasta) 01.assembles/flye.asm.fa

# Part 5: nextdenovo
log "Part 5: Running nextdenovo..."

# Create input.fofn with HiFi files
echo "${HIFI}" | tr ' ' '\n' > input.fofn

# Copy and update nextdenovo.cfg
NEXTDENOVO_CFG=$(realpath $(dirname $(realpath $0))/utils/nextdenovo/nextdenovo.cfg)
cp ${NEXTDENOVO_CFG} ./nextdenovo.cfg
sed -i "s/genome_size = .*/genome_size = ${GENOMESIZE}/" nextdenovo.cfg

# Run nextdenovo
nextdenovo nextdenovo.cfg
ln -s $(realpath ${PWD}/03.ctg_graph/03.ctg_graph/nextgraph.gfa) 01.assembles/nextdenovo.asm.fa

log "Section 1: Assembly completed. All results are in the 01.assembles directory."

# Section 2: Evaluation
log "Section 2: Evaluation"

# Part 1: Running quast...
quast -o 02.asm_eval -t ${CPU} 01.assembles/*.fa

log "Section 2: Evaluation completed. Results are in the 02.asm_eval directory."

# Section 3: Scaffolding
log "Section 3: Scaffolding"

# Part 1: Running Juicer...
python ${JUICER_DIR}/misc/generate_site_positions.py DpnII genome 01.assembles/hifiasm.asm.fa
awk 'BEGIN{OFS="\t"}{print $1, $NF}' genome_DpnII.txt > genome.chrom.size

# Create fastq directory and link files
mkdir -p 03.scaffolding/fastq
ln -s ${HIC1} 03.scaffolding/fastq/sui.HIC_R1.fastq.gz
ln -s ${HIC2} 03.scaffolding/fastq/sui.HIC_R2.fastq.gz
ln -s $(realpath 01.assembles/hifiasm.asm.fa) 03.scaffolding/

# Run Juicer script
bash ${JUICER_DIR}/CPU/juicer.sh -g bs -d 03.scaffolding -D ${JUICER_DIR}/CPU -z 03.scaffolding/hifiasm.asm.fa -y 03.scaffolding/genome_DpnII.txt -p 03.scaffolding/genome.chrom.size -s DpnII -t ${CPU}

# Part 2: Running 3d-dna...
${JUICER_DIR}/3d-dna/run-asm-pipeline.sh -r 0 03.scaffolding/hifiasm.asm.fa 03.scaffolding/aligned/merged_nodups.txt

# Create a symbolic link to the final fasta file
ln -s $(realpath 03.scaffolding/hifiasm.asm.final.fasta) 03.scaffolding/scaffolding.3ddna.fa

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

# Remove duplicates using cd-hit
cd-hit -i 04.gapClose/all_contigs.fa -o 04.gapClose/all_contigs.cdhit.fa -c 0.99 -n 10 -T ${CPU}

# Part 2: Running QuarTeT for gap closing...
quartet -t ${CPU} -g 03.scaffolding/scaffolding.3ddna.fa -c 04.gapClose/all_contigs.cdhit.fa -o 04.gapClose/scaffolding.3ddna.gapclosed.fa

log "Section 4: GapClose completed. Results are in the 04.gapClose directory."

# Section 5: Final Evaluation
log "Section 5: Final Evaluation"

# Part 1: Running quast...
quast -o 05.final_eval/quast -t ${CPU} 04.gapClose/scaffolding.3ddna.gapclosed.fa

# Part 2: Running busco...
busco -i 04.gapClose/scaffolding.3ddna.gapclosed.fa -o 05.final_eval/busco -l <busco_dataset> -m genome -c ${CPU}

log "Section 5: Final Evaluation completed. Results are in the 05.final_eval directory."
