#!/usr/bin/env nextflow

/**************
 * Parameters
 **************/

params.bam 		= "../bams/*.bam"
params.fragment_len  	= '180'
params.fragment_sd  	= '20'
params.bootstrap     	= '100'
params.seqtype 		= 'SR' // 'PR'
params.strand 		= 'rf-stranded'//  fr-stranded,  NULL
params.output        	= "results/"
params.info 		= 'info.tab' // name, type, condition  
params.anno_set 	= "tair10"// "araport_genes" // "tair10"  
params.contrast         = "contrasts.tab"  
params.pvalue		= 0.1
params.binsize		= 10

//fasta_dna, fasta, gtf, params.normtosize, txdb, 

/***************
 *  annotation set selection
 ***************/

if(params.anno_set == "tair10"){
	params.fasta_dna = file("/lustre/scratch/projects/berger_common/backup_berger_common/fasta/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa")
	params.gtf = file("/lustre/scratch/projects/berger_common/backup_berger_common/gtf/Arabidopsis_thaliana.TAIR10.35.gtf") 
	params.fasta = file("/lustre/scratch/projects/berger_common/backup_berger_common/fasta/Arabidopsis_thaliana.TAIR10.cdna.all.fa")
	params.starDir = "star_tair10"
	params.kallistoDir = "tair10_transcripts.idx"
	params.normtosize = '119146348'
	params.txdb="tair10"
}

if(params.anno_set == "araport_genes"){
	params.fasta_dna = file("/lustre/scratch/projects/berger_common/backup_berger_common/fasta/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa")
	params.gtf = file("/lustre/scratch/projects/berger_common/backup_berger_common/gtf/Araport11_GFF3_genes_transposons.201606.gtf") 
	params.fasta = file("/lustre/scratch/projects/berger_common/backup_berger_common/fasta/Araport11_genes.201606.cdna.fasta.gz")
	params.starDir = "star_araport"
	params.kallistoDir = "araport_genes.idx"
	params.normtosize = '119146348'
	params.txdb=file("/lustre/scratch/projects/berger_common/backup_berger_common/araport11.txdb")
}

report = file("report/deseq2.Rmd")

log.info "RNA-SEQ N F  ~  version 0.1"
log.info "====================================="
log.info "bam files         	: ${params.bam}"
log.info "fragment length 	: ${params.fragment_len}"
log.info "fragment sd		: ${params.fragment_sd}"
log.info "bootstrap		: ${params.bootstrap}"
log.info "seq type 		: ${params.seqtype}"
log.info "strandness		: ${params.strand}"
log.info "output		: ${params.output}"
log.info "sample info 		: ${params.info}"
log.info "annotations		: ${params.anno_set}"
log.info "contrasts		: ${params.contrast}"
log.info "p-value 		: ${params.pvalue}"
log.info "norm. size		: ${params.normtosize}"
log.info "binsize		: ${params.binsize}"
log.info "txdb 			: ${params.txdb}"
log.info "fasta dna		: ${params.fasta_dna}"
log.info "fasta			: ${params.fasta}"
log.info "\n"


new File('param.txt').delete()
def file1 = new File('param.txt')

file1 <<  "RNA-SEQ N F  ~  version 0.1 \n"
file1 <<  "===================================== \n"
file1 <<  "bam files             : ${params.bam} \n"
file1 <<  "fragment length       : ${params.fragment_len} \n"
file1 <<  "fragment sd           : ${params.fragment_sd} \n"
file1 <<  "bootstrap             : ${params.bootstrap} \n"
file1 <<  "seq type              : ${params.seqtype} \n"
file1 <<  "strandness            : ${params.strand} \n"
file1 <<  "output                : ${params.output} \n"
file1 <<  "sample info           : ${params.info} \n"
file1 <<  "annotations           : ${params.anno_set} \n"
file1 <<  "contrasts             : ${params.contrast} \n"
file1 <<  "p-value               : ${params.pvalue} \n"
file1 <<  "norm. size            : ${params.normtosize} \n"
file1 <<  "binsize               : ${params.binsize} \n"
file1 <<  "txdb                  : ${params.txdb} \n"
file1 <<  "fasta dna             : ${params.fasta_dna} \n"
file1 <<  "fasta                 : ${params.fasta} \n"



mypar = file('param.txt')
mod = file('nextflow.config') //modules loaded

/*********************************************
**********************************************
ANALYSIS START
**********************************************
*********************************************/

/*
 * Input parameters validation
 */

design = file(params.info)
contrasts = file(params.contrast) 
fasta = file(params.fasta)
gtf = file(params.gtf)

/*
 * validate input files
 */

if( !design.exists() ) exit 1, "Missing sample info file: ${design}"
if( !contrasts.exists() ) exit 1, "Missing contrast file: ${contrasts}"
// contrasts

/***********************
 * Channel for bam files
 ***********************/

bam_files = Channel
          .fromPath(params.bam)
          .map { file -> [ id:file.baseName,file:file] }


/***********************
* Keeping track of moduls
************************/

process track {
	input:
	file mod
	
	output:
	file "modules.txt" into modules

	script:
	"""
	grep "module" ${mod} | tr -d ' ' | tr -d \"\t" | sed 's/module=//g' |   tr -d \\'  | awk 'BEGIN{RS=":"} {print}' | sort | uniq > modules.txt
	"""
}


/********************** 
 * SORT BAM
 **********************/

process sortBam {
tag "sort: $id"

        input:
        set id, file(bam) from bam_files

        output:
        set id, file("${id}.sort.bam") into bam_sorted
	
        script:
        """
        samtools sort -n $bam -o ${id}.sort.bam
        """
}

/*********************
 * BAM TO FASTQ
 *********************/

process generateFastq {
tag "bam : $name, type:$params.seqtype"


        input:
        set  name, file(bam) from bam_sorted

        output:
        set name, file('*.fastq') into fastqs

        script:
        if (params.seqtype=='SR'){
        """
        bedtools bamtofastq -i ${bam} -fq ${name}_1.fastq
        """
        }
        else {
        """
        bedtools bamtofastq -i ${bam} -fq ${name}_1.fastq -fq2 ${name}_2.fastq
        """
        }
}

/***********************
 * COPY CHANNEL
 ***********************/

fastqs.into { fastqs_kallisto; fastqs_star }


/***********************
 * KALLISTO INDEX IF NEEDED
************************/

process kallistoIndex {
tag "dir: $params.kallistoDir"
storeDir '/lustre/scratch/projects/berger_common/backup_berger_common'

   	input:
    	file fasta

    	output:
    	file "${params.kallistoDir}" into transcriptome_index

    	script:
    	"""
    	kallisto index -i ${params.kallistoDir} ${fasta} 
    	"""
}

/*************************
 *  KALLIST QUANT
 *************************/

process quantKallisto {
tag "fq: $name "

	input:
    	file index from transcriptome_index
    	set name, file(fq) from fastqs_kallisto

    	output:
    	file "kallisto_${name}" into kallisto_dirs

    	script:
    	def single = fq instanceof Path
    	if( single  && params.strand ==null) {
    	"""
	mkdir kallisto_${name}
    	kallisto quant -i ${index} -o kallisto_${name}  --single -l ${params.fragment_len} -s ${params.fragment_sd} -b ${params.bootstrap} ${fq}  
    	"""
    	}
    	else if( single ){
        """
        mkdir kallisto_${name}
        kallisto quant -i ${index} -o kallisto_${name} --${params.strand} --single -l ${params.fragment_len} -s ${params.fragment_sd} -b ${params.bootstrap} ${fq}
        """
	}
	else if (params.strand ==null) {
    	"""
	mkdir kallisto_${name}
    	kallisto quant -i ${index} -o kallisto_${name} -b ${params.bootstrap} ${fq}
    	"""
    	}
	else {
	"""
        mkdir kallisto_${name}
        kallisto quant -i ${index} -o kallisto_${name} -b --${params.strand} ${params.bootstrap} ${fq}
	"""
	}
}

/*****************************
 *  COMBINE KALLISTO OUTPUT
 *****************************/

kallisto_dirs.into{kallisto_dirs; kallisto_dirs_deseq2}

process kallistoCountMatrix {
	tag "anno: ${params.anno_set}"
	publishDir "$params.output/kallisto_data" , mode: 'copy'

	input:
	file 'kallisto/*' from kallisto_dirs.collect() 
	
	output:
	file 'kallisto_counts.tab' 

	script:
	"""
	singularity exec /lustre/scratch/projects/berger_common/singularity_images/rna_seq1.simg Rscript $baseDir/bin/sumkallisto.R kallisto ${params.txdb} ${design}
	"""
}

/**************************** 
 * STAR INDEX IF NEEDED
 ****************************/
	
process STARindex {
	tag "dir: $params.starDir"
	storeDir '/lustre/scratch/projects/berger_common/backup_berger_common/'

   	input:
    	file gtf

    	output: 
    	file "${params.starDir}" into star_index

    	script:
    	"""
    	mkdir -p  ${params.starDir}
    	STAR --runThreadN 4 --runMode genomeGenerate --genomeDir ${params.starDir} --genomeFastaFiles ${params.fasta_dna} --sjdbGTFfile ${params.gtf} 
   	 """
}

/***************************
 * STAR ALIGN
 ***************************/

process STAR {
	tag "star: $name"

   	input:
    	file index from star_index
    	set name, file(fq) from fastqs_star
    
    	output:
	set name, file("star_${name}/${name}Aligned.sortedByCoord.out.bam") into sort_bam    
	file("star_${name}/${name}Log.final.out") into final_log    
    	file "star_${name}/${name}ReadsPerGene.out.tab" into starcount

    	script:
    	"""
	mkdir -p star_${name}
    	STAR --genomeDir $index --outFileNamePrefix ./star_${name}/${name} --readFilesIn  $fq --runThreadN 4 --quantMode GeneCounts --outSAMtype BAM SortedByCoordinate 
    	"""
}

process STAR_log {
 	publishDir "$params.output/star_data" , mode: 'copy'
	input:
	file 'logs/*' from final_log.collect()

	output:
	file "star_stats.tab" into stats	

	script:
	"""
	bash star_stats.sh
	"""
}

/***************************
 * COMBINE STAR COUNTS
 **************************/ 

process starCountMatrix {

	tag "strand: ${params.strand}"
  	publishDir "$params.output/star_data" , mode: 'copy'

	input:
	file 'star/*' from starcount.collect()
	
	output:
	file 'star_counts.tab'
	
	script:
	"""
	singularity exec /lustre/scratch/projects/berger_common/singularity_images/rna_seq1.simg Rscript $baseDir/bin/sumstar.R star ${params.strand} ${design} 
	"""
}

/*****************************
 * BAM 2 BW
 ****************************/

process bam2bw {
	publishDir "$params.output/bam_bw", mode: 'copy'
        tag "bw: $name"

	input:
	set name, file(bam) from sort_bam


	output:
	file("${name}.bw")
	
	script:
	"""
	export TMPDIR=\$(pwd)
   	samtools index ${bam}
   	bamCoverage -b ${bam} -o ${name}.bw --normalizeTo1x ${params.normtosize} --binSize=${params.binsize}	
	"""
}

/*****************************
* DESeq2
*****************************/

process deseq2 {
publishDir "$params.output/deseq", mode: 'copy'

 	input:
  	file 'kallisto/*' from kallisto_dirs_deseq2.collect()
  	file design
  	file contrasts
  
  	output:
  	file 'pairs.png' into pair
  	file 'dds.Rdata' into dds
  	file 'pca.png' into pca
  	file 'maplot_*' into maplots
  	file 'contrast_*' into results
  	file 'sessionInfo_deseq2.txt' into seinfo
  	file 'barplot_*' into barplots
	file 'Rarguments.txt' into argument

 	script:
  	"""
        singularity exec /lustre/scratch/projects/berger_common/singularity_images/rna_seq1.simg Rscript $baseDir/bin/deseq2.R kallisto ${design} ${contrasts} ${params.pvalue} ${params.txdb} $workflow.sessionId
 	 """
}

/*******************************
*report {
*******************************/

process report {
publishDir "$params.output/report", mode: 'copy'

        input:
	file stats from stats
	file mods from modules
	file pairplot from pair
	file pcaplot from pca
	file 'lists/*' from results.collect()
	file 'maplots/*' from maplots.collect() 
	file session from seinfo 	
	file mypar
	file 'barplots/*' from barplots.collect() 	
	file args from argument	

	output:
 	file 'report.html'
	file 'deseq_contrast.Rmd'
	file 'report.Rmd'

	script:
 	"""
        cp -L $baseDir/report/deseq_contrast.Rmd . 
	cp -L $baseDir/report/report.Rmd .
	singularity exec /lustre/scratch/projects/berger_common/singularity_images/rna_seq1.simg Rscript $baseDir/bin/createReport.R ${design} ${params.pvalue}  ${contrasts} $workflow.sessionId
        """
}

/********************************
process config
********************************/

process config {
publishDir "$params.output/nextflow", mode: 'copy'
	
	input:
	
	output:
	file 'nextflow.config'
	file 'rna_seq1.nf'

	script:
	"""
	cp  $baseDir/nextflow.config .
	cp  $baseDir/rna_seq1.nf .
	"""
}

/********************************
process script
********************************/

process script {
publishDir "$params.output/used_script", mode: 'copy'

	input:
	
	output:
	file 'deseq2.R'
	file 'createReport.R'
	file 'star_stats.sh'
	file 'sumkallisto.R'
	file 'sumstar.R'

	script:
	"""
	cp  $baseDir/bin/deseq2.R .
	cp  $baseDir/bin/createReport.R .
	cp  $baseDir/bin/star_stats.sh .
	cp  $baseDir/bin/sumkallisto.R .
	cp  $baseDir/bin/sumstar.R .
	"""
}
 

workflow.onComplete { 	
new File('param.txt').delete() // cleaning up
println ( workflow.success ? "Done!" : "Oops .. something went wrong" )
}

  	
	
