
# CompHiFi (Comprehensive HiFi Assembler)

CompHiFi is a comprehensive genome assembly pipeline designed to handle High-Fidelity (HiFi) sequencing data. It automates the entire process from data preparation, assembly, scaffolding, gap closing, to evaluation, using a variety of state-of-the-art tools.

## Features

1. **Combines the advantages of multiple assembly tools**:
    - Utilizes hifiasm, verkko, canu, flye, and nextdenovo to fully leverage HiFi data, providing more accurate and reliable genome assembly results.

2. **One-click workflow completion**:
    - Offers a one-click solution to automate the entire process of genome assembly, scaffolding, gap filling, and evaluation.

3. **Gap filling using results from multiple assembly tools**:
    - Uses cd-hit to integrate results from multiple assembly tools, efficiently filling gaps in the genome assembly to enhance quality.

## Dependencies

Ensure the following tools are installed and accessible in your PATH:

- hifiasm
- verkko
- canu
- flye
- nextdenovo
- quast
- juicer
- 3ddna
- seqkit
- cd-hit
- quartet
- busco
- merqury

## Installation

Clone the repository to your local machine and add the directory to your PATH:

```bash
git clone https://github.com/your/compHiFi.git
cd compHiFi
export PATH=$(pwd):$PATH
```

Ensure all dependencies are installed. Follow the installation instructions for each tool on their respective websites.

## Usage

Prepare your input data. Ensure that you have HiFi reads in FASTA format (`--hifi`), Hi-C reads in two separate FASTQ files (`--hic1` and `--hic2`), and specify a genome size (`--genomeSize`).

```bash
genome_assembly_pipeline.sh --hifi <HiFi_reads> --hic1 <Hi-C_reads1> --hic2 <Hi-C_reads2> --genomeSize <genome_size> [--prefix <prefix>] [--cpu <num_cpus>]
```

### Required parameters:
- `--hifi`: HiFi reads in FASTQ/FASTA format (space-separated for multiple files)
- `--hic1`: Hi-C reads (R1) in FASTQ format
- `--hic2`: Hi-C reads (R2) in FASTQ format
- `--genomeSize`: Estimated genome size

### Optional parameters:
- `--prefix`: Prefix for output files (default: 'result')
- `--cpu`: Number of CPUs to use (default: all available CPUs)


### Example Command

```bash
bash genome_assembly_pipeline.sh --hifi /path/to/hifi1.fastq.gz /path/to/hifi2.fastq.gz --hic1 /path/to/hic1.fastq --hic2 /path/to/hic2.fastq --genomeSize 3.2g --prefix mygenome --cpu 16
```

The pipeline will generate the assembled genome in the `03.scaffolding/scaffolding.3ddna.gapclosed.fa` file, along with evaluation results in the `02.asm_eval` and `05.final_eval` directories.

For any issues or questions regarding the usage of this tool, please contact the author.

## Contributors

- Han Yang <yhan@zju.edu.cn>

## License

This project is licensed under the MIT License - see the LICENSE file for details.

