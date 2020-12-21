# YAY INSTALLS 
#yay -S pip samtools htslib

source venv/bin/activate 
# check for RNA Tumor bam 
homedir=$(pwd)
DATA=https://xfer.genome.wustl.edu/gxfer1/project/gms/testdata/bams/hcc1395
#RNA_TUMOR_BASE=gerald_C1TD1ACXX_8_ACAGTG
#RNA_TUMOR=/scratch/drkthomp/fullbams/${RNA_TUMOR_BASE}.sorted.bam
RNA_TUMOR_BASE=rna_genome_sorted
RNA_TUMOR=${homedir}/${RNA_TUMOR_BASE}.bam
RNA_TUMOR_MD=${homedir}/${RNA_TUMOR_BASE}md.bam
RNA_NORMAL=/scratch/drkthomp/fullbams/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna
PICARD=picard.jar 

if [ -f "$PICARD" ]; then
      echo "$PICARD exists."
    else
      wget https://github.com/broadinstitute/picard/releases/download/2.23.9/picard.jar $PICARD
fi
if [ -f "$RNA_NORMAL" ]; then
    echo "$RNA_NORMAL exists."
   else
    wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz ${RNA_NORMAL}.gz 
    gunzip ${RNA_NORMAL}.gz
fi
if [ -f "$RNA_TUMOR_MD" ]; then
      echo "$RNA_TUMOR_MD exists."
    else 
      if [ -f "$RNA_TUMOR" ]; then
          echo "$RNA_TUMOR exists."
        else
          wget ${DATA}/${RNA_TUMOR_BASE}.bam
          samtools sort ${RNA_TUMOR_BASE}.bam ${RNA_TUMOR}
      fi
      samtools calmd ${RNA_TUMOR} ${RNA_NORMAL} > ${RNA_TUMOR_MD}

fi
if [ -f "${RNA_TUMOR}.bai" ]; then
      echo "${RNA_TUMOR}.bai exists."
    else
      samtools index -b $RNA_TUMOR
      echo "{RNA_TUMOR}.bai created"
fi

PROCESSED=opossum_${RNA_TUMOR_BASE}.bam
OPOSSUM=Opossum.py
if [ -f "$OPOSSUM" ]; then 
    echo "$OPOSSUM exists."
  else
    wget -O $OPOSSUM https://raw.githubusercontent.com/BSGOxford/Opossum/master/Opossum.py
    2to3 -w $OPOSSUM 
fi
# pip dependencies for opossum 
pip install pysam 

#woot 
if [ -f "${PROCESSED}" ]; then
    echo "${PROCESSED} exists."
  else
    python $OPOSSUM --BamFile=$RNA_TUMOR --OutFile=$PROCESSED --SoftClipsExist=True 
fi 
# okay install HTSLib
HTSLIB_TAR=htslib-1.11
if [ -f "${HTSLIB_TAR}.tar.bz2" ]; then
    echo "${HTSLIB_TAR} exists."
  else
    wget -O ${HTSLIB_TAR}.tar.bz2 https://github.com/samtools/htslib/releases/download/1.11/htslib-1.11.tar.bz2
    tar -xf ${HTSLIB_TAR}.tar.bz2
    cd $HTSLIB_TAR
    make install prefix=${homedir}/htslib
    # had to run these manually
    export C_INCLUDE_PATH=${homedir}/htslib/include
    export LIBRARY_PATH=${homedir}/htslib/lib
    export LD_LIBRARY_PATH=${homedir}/htslib/lib
fi
cd $homedir
PLATYPUS_DIR=platypus
PLATYPUS=${PLATYPUS_DIR}/bin/Platypus.py
if [ -f "$PLATYPUS" ]; then
    echo "$PLATYPUS exists."
  else
    git clone --depth=1 --branch=master https://github.com/andyrimmer/Platypus.git ${PLATYPUS_DIR}
    rm -rf ./${PLATYPUS_DIR}/.git
    cd ${PLATYPUS_DIR}
    make
fi
cd $homedir
#2to3 -w ${PLATYPUS_DIR}/
python2 ${PLATYPUS} callVariants --bamFiles=${PROCESSED} --refFile=${RNA_NORMAL} --filterDuplicates=0 --minMapQual=0 --minFlank=0 --maxReadLength=500 --minGoodQualBases=10 --minBaseQual=20 --output=variants_${RNA_TUMOR_BASE}.vcf
