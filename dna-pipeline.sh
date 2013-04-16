#!/bin/bash -l
#SBATCH -A a2009002
#SBATCH -p core
#SBATCH -n 1
#SBATCH -t 120:00:00
#SBATCH -J snp_seq_pipeline_controller
#SBATCH -o pipeline-%j.out
#SBATCH -e pipeline-%j.error
#SBATCH --qos=seqver

# NOTE
# LOOK AT THE BOTTOM OF THE SCRIPT TO SEE SETUP ETC.

#------------------------------------------------------------------------------------------
# Functions below run the different qscripts and return end by echoing a path to the
# output cohort file (or something similar). This can then be feed to the next part of
# the pipeline  to chain the scripts together, provided that they have compatiable
# output types.
#------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------
# Align fastq files using bwa - outputs bam files.
#------------------------------------------------------------------------------------------
function alignWithBwa {
    source piper -S ${SCRIPTS_DIR}/AlignWithBWA.scala \
			    -i $1 \
			    -outputDir ${RAW_BAM_OUTPUT}/ \
			    -bwa ${PATH_TO_BWA} \
			    -samtools ${PATH_TO_SAMTOOLS} \
			    -bwape \
			    --bwa_threads ${NBR_OF_THREADS} \
	            -jobRunner ${JOB_RUNNER} \
        		-jobNative "${JOB_NATIVE_ARGS}" \
			    --job_walltime 345600 \
			    -run \
			    ${DEBUG} >> ${LOGS}/alignWithBwa.log  2>&1


    # Check the script exit status, and if it did not finish, clean up and exit
    if [ $? -ne 0 ]; then 
	    echo "Caught non-zero exit status from AlignWithBwa. Cleaning up and exiting..."
	    clean_up
	    exit 1
    fi

    echo "${RAW_BAM_OUTPUT}/${PROJECT_NAME}.cohort.list"
}

#------------------------------------------------------------------------------------------
# NOTE: These parts of the analysis does not yet suport the xml based setup.
#       Running them will require manually setting up path etc.
#------------------------------------------------------------------------------------------


#------------------------------------------------------------------------------------------
# CalculateCoverage of bam-files
#------------------------------------------------------------------------------------------
function alignmentQC {
    source piper -S ${SCRIPTS_DIR}/AlignmentQC.scala \
			    -i $1 \
    			-R ${GENOME_REFERENCE} \
 			    -intervals ${INTERVALS} \
			    -outputDir ${ALIGNMENT_QC_OUTPUT}/ \
			    -nt ${NBR_OF_THREADS} \
	            -jobRunner ${JOB_RUNNER} \
        		-jobNative "${JOB_NATIVE_ARGS}" \
			    --job_walltime 345600 \
			    -run \
			    ${DEBUG} >> ${LOGS}/alignmentQC.log  2>&1


    # Check the script exit status, and if it did not finish, clean up and exit
    if [ $? -ne 0 ]; then 
	    echo "Caught non-zero exit status from alignmentQC. Cleaning up and exiting..."
	    clean_up
	    exit 1
    fi

    echo "${RAW_BAM_OUTPUT}/${PROJECT_NAME}.cohort.list"
}


#------------------------------------------------------------------------------------------
# Data preprocessing
#------------------------------------------------------------------------------------------
function dataPreprocessing {

    source piper -S ${SCRIPTS_DIR}/DataProcessingPipeline.scala \
			      -R ${GENOME_REFERENCE} \
			      --project ${PROJECT_NAME} \
			      -i $1 \
			      -outputDir ${PROCESSED_BAM_OUTPUT}/ \
        		  --dbsnp ${DB_SNP} \
                  --extra_indels ${MILLS} \
          		  --extra_indels ${ONE_K_G} \
			      -intervals ${INTERVALS} \
			      -cm USE_SW \
			      -run \
		          -jobRunner ${JOB_RUNNER} \
         	      -jobNative "${JOB_NATIVE_ARGS}" \
			      --job_walltime 864000 \
			      -nt ${NBR_OF_THREADS} \
			      ${DEBUG} >> ${LOGS}/dataPreprocessing.log  2>&1

    # Check the script exit status, and if it did not finish, clean up and exit
    if [ $? -ne 0 ]; then 
            echo "Caught non-zero exit status from DataProcessingPipeline. Cleaning up and exiting..."
            clean_up
            exit 1
    fi
    
    echo "${PROCESSED_BAM_OUTPUT}/${PROJECT_NAME}.cohort.list"

}

#------------------------------------------------------------------------------------------
# Variant calling
#------------------------------------------------------------------------------------------

function variantCalling {

    source piper -S ${SCRIPTS_DIR}/VariantCalling.scala \
			      -R ${GENOME_REFERENCE} \
			      -res ${GATK_BUNDLE} \
			      --project ${PROJECT_NAME} \
			      -i ${PROCESSED_BAM_OUTPUT}/${PROJECT_NAME}.cohort.list \
			      -intervals ${INTERVALS} \
			      -outputDir ${VCF_OUTPUT}/ \
			      -run \
		          -jobRunner ${JOB_RUNNER} \
                  -jobNative "${JOB_NATIVE_ARGS}" \
			      --job_walltime 3600 \
			      -nt  ${NBR_OF_THREADS} \
			      -retry 2 \
			      ${DEBUG} >> ${LOGS}/variantCalling.log  2>&1

    # Check the script exit status, and if it did not finish, clean up and exit
    if [ $? -ne 0 ]; then 
            echo "Caught non-zero exit status from VariantCalling. Cleaning up and exiting..."
            clean_up
            exit 1
    fi
    
    echo "${VCF_OUTPUT}/${PROJECT_NAME}.cohort.list"
}

# We also need the correct java engine and R version
module load java/sun_jdk1.6.0_18
module load R/2.15.0
module load bioinfo-tools
module load bwa/0.6.2
module load samtools/0.1.18

#---------------------------------------------
# Run template - setup which files to run etc
#---------------------------------------------

PIPELINE_SETUP_XML="src/test/resources/testdata/pipelineSetup.xml"
PROJECT_NAME="TestProject"
PROJECT_ID="a2009002"
# Note that it's important that the last / is included in the root dir path
PROJECT_ROOT_DIR="/local/data/SnpSeqPipelineIntegrationTestData/"
INTERVALS=""
GENOME_REFERENCE=${GATK_BUNDLE}"/human_g1k_v37.fasta"

#---------------------------------------------
# The actual running of the script
# Modify this if you want to chain the parts
# in a different way.
#---------------------------------------------

# Loads the global settings. To change them open globalConfig.sh and rewrite them.
source globalConfig.sh

ALIGN_OUTPUT=$(alignWithBwa ${PIPELINE_SETUP_XML})
ALIGN_QC_OUTPUT=$(alignmentQC ${ALIGN_OUTPUT})
DATAPROCESSING_OUTPUT=$(dataPreprocessing ${ALIGN_OUTPUT})
VARIANTCALLING_OUTPUT=$(variantCalling ${DATAPROCESSING_OUTPUT})

# Perform final clean up
final_clean_up

#TODO Fix mechanism for setting walltimes.