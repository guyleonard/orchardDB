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
# Archaeplastida
#
echo "[OrchardDB:CREATE:INFO] - Downloading Archaeplastida Genomes"
./get_archaeplastida_genomes.sh
mkdir -p ${DB}/archaeplastida
echo "[OrchardDB:CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[OrchardDB:CREATE:INFO] - Move Original FASTA Records"
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa *.txt ${DB}/archaeplastida
echo "[OrchardDB:CREATE:INFO] - Insert Archaeplastida Genomes"
./insert_archaeplastida_genomes.sh ${USER} ${PASS} ${DB}
echo "[OrchardDB:CREATE:INFO] - GZIP Original Archaeplastida FASTA Records"
pigz -9 -R ${DB}/archaeplastida/*

#
# Metazoa
#
echo "[OrchardDB:CREATE:INFO] - Downloading metazoa Genomes"
./get_metazoan_genomes.sh
mkdir -p ${DB}/metazoa
echo "[OrchardDB:CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[OrchardDB:CREATE:INFO] - Move Original FASTA Records"
mv *.fa *.faa *.fasta *.prot ${DB}/metazoa
echo "[OrchardDB:CREATE:INFO] - Insert metazoa Genomes"
./insert_metazoan_genomes.sh ${USER} ${PASS} ${DB}
echo "[OrchardDB:CREATE:INFO] - GZIP Original metazoa FASTA Records"
pigz -9 -R ${DB}/metazoa/*

#
# Protists
#
echo "[OrchardDB:CREATE:INFO] - Downloading protist Genomes"
./get_protist_genomes.sh
mkdir -p ${DB}/protists
echo "[OrchardDB:CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[OrchardDB:CREATE:INFO] - Move Original FASTA Records"
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa ${DB}/protists
echo "[OrchardDB:CREATE:INFO] - Insert protist Genomes"
./insert_protist_genomes.sh ${USER} ${PASS} ${DB}
echo "[OrchardDB:CREATE:INFO] - GZIP Original protist FASTA Records"
pigz -9 -R ${DB}/protists/*

#
# Fungi
#
echo "[OrchardDB:CREATE:INFO] - Downloading Fungal Genomes"
./get_fungal_genomes.sh
mkdir -p ${DB}/fungi
echo "[OrchardDB:CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[OrchardDB:CREATE:INFO] - Move Original FASTA Records"
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa ${DB}/fungi
echo "[OrchardDB:CREATE:INFO] - Insert Fungal Genomes"
./insert_fungal_genomes.sh ${USER} ${PASS} ${DB}
echo "[OrchardDB:CREATE:INFO] - GZIP Original Fungal FASTA Records"
pigz -9 -R ${DB}/fungi/*

#
# Prokaryotes
#
echo "[OrchardDB:CREATE:INFO] - Downloading Prokaryote Genomes"
./get_prokaryote_genomes.sh
mkdir -p ${DB}/prokaryotes
echo "[OrchardDB:CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[OrchardDB:CREATE:INFO] - Move Original FASTA Records"
mv *.faa ${DB}/prokaryotes
echo "[OrchardDB:CREATE:INFO] - Insert Prokaryote Genomes"
./insert_prokaryote_genomes.sh ${USER} ${PASS} ${DB}
echo "[OrchardDB:CREATE:INFO] - GZIP Original Prokaryote FASTA Records"
pigz -9 -R ${DB}/prokaryotes/*

echo "[OrchardDB:CREATE:INFO] - Making BLAST Databases"
for i in ${DB}/*.fasta; do
	makeblastdb -in ${i} -dbtype prot -parse_seqids
done

#for i in ${DB}/*.fasta; do
#	diamond makedb --in ${i} -d ${i}
#done

echo "[OrchardDB:CREATE:INFO] - Finished!"
exit 0
