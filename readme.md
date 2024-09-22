
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

- [hifiasm](https://github.com/chhylp123/hifiasm)
- [verkko](https://github.com/marbl/verkko)
- [canu](https://github.com/marbl/canu)
- [Flye](https://github.com/mikolmogorov/Flye)
- [NextDenovo](https://github.com/Nextomics/NextDenovo)
- [quast](https://github.com/ablab/quast)
- [seqkit](https://github.com/shenwei356/seqkit)
- [quartet](https://github.com/aaranyue/quarTeT)
- [busco](https://gitlab.com/ezlab/busco)
- [merqury](https://github.com/marbl/merqury)

## Installation

Clone the repository to your local machine and add the directory to your PATH:

```bash
git clone https://github.com/eric-hy/compHiFi.git
cd compHiFi
export PATH=$(pwd):$PATH
```

Ensure all dependencies are installed. Follow the installation instructions for each tool on their respective websites. Alternatively, we **strongly recommend** using our Docker image, where all dependencies and the environment are pre-configured, allowing the entire workflow to run directly.

```shell
docker pull yhan0727/comphifi:v0.2
```

*tips: A proxy might be necessary in some regions.



## Usage

Prepare your input data. Ensure that you have HiFi reads in FASTA format (`--hifi`), Hi-C reads in two separate FASTQ files (`--hic1` and `--hic2`), and specify a genome size (`--genomeSize`).

```bash
compHifi.sh --hifi <HiFi_reads> --hic1 <Hi-C_reads1> --hic2 <Hi-C_reads2> --genomeSize <genome_size> [--prefix <prefix>] [--cpu <num_cpus>] [--review]
```

### Required parameters:
- `--hifi`: HiFi reads in FASTQ/FASTA format (space-separated for multiple files)
- `--hic1`: Hi-C reads (R1) in FASTQ format
- `--hic2`: Hi-C reads (R2) in FASTQ format
- `--genomeSize`: Estimated genome size

### Optional parameters:
- `--prefix`: Prefix for output files (default: 'species')
- `--cpu`: Number of CPUs to use (default: all available CPUs)
- `--review`: Enable review mode, pause pipeline for manual review with [Juicebox](https://github.com/aidenlab/Juicebox).

### Example Command

In the `sample` folder, we have prepared a small mock dataset to demonstrate how our pipeline works and to verify that the runtime environment is properly configured. Using this dataset, a typical command is as follows:

```bash
bash compHifi.sh --hifi sample/hifi.fq.gz --hic1 sample/hic_1.fq.gz --hic2 sample/hic_2.fq.gz --genomeSize 5M --prefix mygenome --cpu 32
```

For running this pipeline with a Docker container, the command is as follows:

```shell
docker run -v $(pwd):/work -w /work -it --rm yhan0727/comphifi:v0.2 compHiFi.sh --hifi sample/hifi.fq.gz --hic1 sample/hic_1.fq.gz --hic2 sample/hic_2.fq.gz --genomeSize 5M
```

Running the test dataset completely takes approximately 30 minutes.

The pipeline will generate the assembled genome in the `04.gapClose/scaffolding.3ddna.gapclosed.fa` file, along with evaluation results in the `02.asm_eval` and `05.final_eval` directories.



##### Resume the pipeline from the assembly reviewed by Juicebox

In some cases, Juicer may incorrectly link Hi-C signals, or 3D-DNA may not optimally divide the chromosomes. In these situations, we need to manually review the results using [Juicebox](https://github.com/aidenlab/Juicebox). The `--review` parameter allows the pipeline to pause at appropriate points, after export the reviewed assembly, we can use the `compHiFi-post-review.sh` script to resume the remaining steps of the pipeline from the appropriate point:

```shell
bash compHifi.sh --hifi sample/hifi.fq.gz --hic1 sample/hic_1.fq.gz --hic2 sample/hic_2.fq.gz --genomeSize 5M --prefix mygenome --cpu 32 --review
# export reviewed assembly file after manual check
bash compHiFi-post-review.sh --assembly 3ddna.hifiasm.asm.final.review.assembly
```

For running this script with a Docker container:

```shell
docker run -v $(pwd):/work -w /work -it --rm yhan0727/comphifi:v0.2 compHiFi.sh --hifi sample/hifi.fq.gz --hic1 sample/hic_1.fq.gz --hic2 sample/hic_2.fq.gz --genomeSize 5M --review
# export reviewed assembly file after manual check
docker run -v $(pwd):/work -w /work -it --rm yhan0727/comphifi:v0.2 compHiFi-post-review.sh --assembly 3ddna.hifiasm.asm.final.review.assembly
```



This script will start from 3D-DNA's `run-asm-pipeline-post-review.sh` and requires a mandatory parameter `--assembly` to specify the reviewed assembly FILENAME, not path, such as `3ddna.hifiasm.asm.final.review.assembly`. **Please note** that the file must be placed in the `03.scaffolding/3d-dna` folder, and the script should be run from within the original working directory.



For any issues or questions regarding the usage of this tool, please contact the author.

## Contributors

- Han Yang <yhan@zju.edu.cn>

## License

This project is licensed under the MIT License - see the LICENSE file for details.

