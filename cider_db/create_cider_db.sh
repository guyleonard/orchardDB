#!/usr/bin/env bash

USER=$1
PASS=$2
DB=$3

NUMARGS=$#

if [ "${NUMARGS}" -eq 0 ]; then
    echo "You are missing paramaters..."
    exit 1
fi

#
# Archaeplastida
#
echo "[CREATE] Creating orchardDB with ${USER}:${PASS}@${DB}"
../bin/plant --setup --user ${USER} --pass ${PASS} --db ${DB}

echo "[CREATE] Downloading Archaeplastida Genomes"
./get_archaeplastida_genomes.sh
echo "[CREATE] UnGzip Files"
pigz -d *.gz

echo "[CREATE] Archaeplastida Genomes"
./insert_archaeplastida_genomes.sh ${USER} ${PASS} ${DB}

echo "[CREATE] Tidying Up"
mkdir -p archaeplastida
echo -e "\tMove Original FASTA Records"
mv *.fa *.fna *.faa *.fasta *.pep *.tfa archaeplastida
echo -e "\tGZIP Original FASTA Records"
pigz -9 -R archaeplastida/* 


exit 0