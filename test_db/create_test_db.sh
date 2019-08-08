#!/usr/bin/env bash

USER=$1
PASS=$2
DB=$3

NUMARGS=$#

if [ "${NUMARGS}" -eq 0 ]; then
    echo "[OrchardDB:CREATE:ERRR] - You are missing paramaters..."
    exit 1
fi

if [[ ! -f nodes.dmp || ! -f names.dmp ]]; then
	echo "[OrchardDB:CREATE:WARN] - The NCBI Taxdmp files are missing!";
	wget -nc ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
	tar zxvf taxdump.tar.gz names.dmp nodes.dmp
	rm taxdump.tar.gz
fi

if [ ! -f taxonomy.sqlite ]; then
	echo "[OrchardDB:CREATE:WARN] - taxonomy.sqlite is Missing. It will be generated on the first pass.";
fi

#
# Setup
#
echo "[OrchardDB:CREATE:INFO] - Creating orchardDB with ${USER}:${PASS}@${DB}"
../bin/plant --setup --user ${USER} --pass ${PASS} --db ${DB}

#
# Genomes
#
echo "[OrchardDB:CREATE:INFO] - Downloading Genomes"
./get_genomes.sh
mkdir -p ${DB}/original
echo "[OrchardDB:CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[OrchardDB:CREATE:INFO] - Move Original FASTA Records"
mv *.fa ${DB}/original
echo "[OrchardDB:CREATE:INFO] - Insert Genomes"
./insert_genomes.sh ${USER} ${PASS} ${DB}
echo "[OrchardDB:CREATE:INFO] - GZIP Original FASTA Records"
pigz -9 -R ${DB}/original/*

echo "[OrchardDB:CREATE:INFO] - Making BLAST Databases"
for i in ${DB}/*.fasta; do
	makeblastdb -in ${i} -dbtype prot -parse_seqids
done

echo "[OrchardDB:CREATE:INFO] - Making DIAMOND Databases"
for i in ${DB}/*.fasta; do
	diamond makedb --in ${i} -d ${i}
done

echo "[OrchardDB:CREATE:INFO] - Finished!"
exit 0
