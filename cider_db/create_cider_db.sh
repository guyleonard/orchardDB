#!/usr/bin/env bash

USER=$1
PASS=$2
DB=$3

NUMARGS=$#

if [ "${NUMARGS}" -eq 0 ]; then
    echo "You are missing paramaters..."
    exit 1
fi

if [[ ! -f nodes.dmp || ! -f names.dmp ]]; then
	echo "The NCBI Taxdmp files are missing!";
	wget -nc ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
	tar zxvf taxdump.tar.gz names.dmp nodes.dmp
	rm taxdump.tar.gz
fi

if [ ! -f taxonomy.sqlite ]; then
	echo "taxonomy.sqlite is Missing. It will be generated on the first pass.";
fi

#
# Setup
#
echo "[CREATE] Creating orchardDB with ${USER}:${PASS}@${DB}"
../bin/plant --setup --user ${USER} --pass ${PASS} --db ${DB}

#
# Archaeplastida
#
echo "[CREATE] Downloading Archaeplastida Genomes"
./get_archaeplastida_genomes.sh
echo -e "\tMove Original FASTA Records"
mkdir -p ${DB}/archaeplastida
echo "[CREATE] UnGzip Files"
pigz -d *.gz
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.tfa ${DB}/archaeplastida
echo "[CREATE] Archaeplastida Genomes"
./insert_archaeplastida_genomes.sh ${USER} ${PASS} ${DB}
echo -e "\tGZIP Original Archaeplastida FASTA Records"
pigz -9 -R ${DB}/archaeplastida/*

#
# Metazoa
#
echo "[CREATE] Downloading Metazoan Genomes"
./get_metazoan_genomes.sh
echo -e "\tMove Original FASTA Records"
mkdir -p ${DB}/metazoa
echo "[CREATE] UnGzip Files"
pigz -d *.gz
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.prot *.tfa ${DB}/metazoa
echo "[CREATE] Metazoa Genomes"
./insert_metazoan_genomes.sh ${USER} ${PASS} ${DB}
echo -e "\tGZIP Original Metazoan FASTA Records"
pigz -9 -R ${DB}/metazoa/*

#
# Protists
#
echo "[CREATE] Downloading Protist Genomes"
./get_protist_genomes.sh
echo -e "\tMove Original FASTA Records"
mkdir -p ${DB}/protists
echo "[CREATE] UnGzip Files"
pigz -d *.gz
mv *.aa *.fa *.fna *.faa *.fasta *.pep *.protein *.prot *.tfa ${DB}/protists
echo "[CREATE] Protist Genomes"
./insert_protist_genomes.sh ${USER} ${PASS} ${DB}
echo -e "\tGZIP Original Protist FASTA Records"
pigz -9 -R ${DB}/protists/* 

exit 0
