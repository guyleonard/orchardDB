#!/usr/bin/env bash

USER=$1
PASS=$2
DB=$3

NUMARGS=$#

if [ "${NUMARGS}" -eq 0 ]; then
    echo "[CREATE:ERRR] - You are missing paramaters..."
    exit 1
fi

if [[ ! -f nodes.dmp || ! -f names.dmp ]]; then
	echo "[CREATE:WARN] - The NCBI Taxdmp files are missing!";
	wget -nc ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
	tar zxvf taxdump.tar.gz names.dmp nodes.dmp
	rm taxdump.tar.gz
fi

if [ ! -f taxonomy.sqlite ]; then
	echo "[CREATE:WARN] - taxonomy.sqlite is Missing. It will be generated on the first pass.";
fi

#
# Setup
#
echo "[CREATE:INFO] - Creating orchardDB with ${USER}:${PASS}@${DB}"
../bin/plant --setup --user ${USER} --pass ${PASS} --db ${DB}

#
# Archaeplastida
#
echo "[CREATE:INFO] - Downloading Archaeplastida Genomes"
./get_archaeplastida_genomes.sh
mkdir -p ${DB}/archaeplastida
echo "[CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[CREATE:INFO] - Move Original FASTA Records"
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa ${DB}/archaeplastida
echo "[CREATE:INFO] - Insert Archaeplastida Genomes"
./insert_archaeplastida_genomes.sh ${USER} ${PASS} ${DB}
echo -e "[CREATE:INFO] - GZIP Original Archaeplastida FASTA Records"
pigz -9 -R ${DB}/archaeplastida/*

#
# Metazoa
#
echo "[CREATE:INFO] - Downloading metazoa Genomes"
./get_metazoan_genomes.sh
mkdir -p ${DB}/metazoa
echo "[CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[CREATE:INFO] - Move Original FASTA Records"
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa ${DB}/metazoa
echo "[CREATE:INFO] - Insert metazoa Genomes"
./insert_metazoan_genomes.sh ${USER} ${PASS} ${DB}
echo -e "[CREATE:INFO] - GZIP Original metazoa FASTA Records"
pigz -9 -R ${DB}/metazoa/*

#
# Protists
#
echo "[CREATE:INFO] - Downloading protist Genomes"
./get_protist_genomes.sh
mkdir -p ${DB}/protists
echo "[CREATE:INFO] - UnGzip Files"
gunzip *.gz
echo "[CREATE:INFO] - Move Original FASTA Records"
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa ${DB}/protists
echo "[CREATE:INFO] - Insert protist Genomes"
./insert_protist_genomes.sh ${USER} ${PASS} ${DB}
echo -e "[CREATE:INFO] - GZIP Original protist FASTA Records"
pigz -9 -R ${DB}/protists/*

exit 0
