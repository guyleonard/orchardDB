# orchardDB
:apple: :deciduous_tree: A script to create and populate a local database and folder-set with amino acid sequences retrieved from a variety of genome portals for use with the Orchard pipeline. Amino acid sequences can be derived from DNA & RNA gene predictions or from EST libraries. Multiple versions of different taxa (e.g. different gene-calling methods or updated genomes) can exist in the database.

## Install
Please make sure all dependencies are currently installed.
```
git clone https://github.com/guyleonard/orchardDB.git
```
### Dependencies
#### Perl
 * Bio::DB::Taxonomy;
 * Bio::SeqIO;
 * DateTime;
 * DBI;
 * Digest::MD5 qw(md5_hex);
 * File::Path qw(make_path);
 * Getopt::Long; 

#### System Tools
 * SQLite 3

## Usage
Firstly you must set up your database, and then secondly populate it with your sequence data as detailed below.

Each 'genome' - loosely used here to represent a set of amino acid sequences that come from the gene predictions of different sequencing projects - is given a unique ID (not an NCBI Taxon ID), allowing for multiple versions and sources of the same taxa. These unique IDs are used to represent the 'genome' in the database and downstream scripts, they can be translated back to a variety of information. Additionally, each sequence is given it's own unique ID, separate to that of the one from it's genome portal.

### Set Up Database
This command will create a directory named "cider" and a SQL DB named "cider.sqlite" in the same directory. This will be your store of information for the whole orchardDB.
```
./bin/plant --setup \     # instruct script to create OrchardDB
            --user test \ # username for OrchardDB
            --pass test \ # password for OrchardDB 
            --db cider    # OrchardDB name
```
### Populate Database
This command will add information to the database and copy your old file to the database directory with new headers. You will need to provide a file of your amino acids in FASTA format, an NCBI Taxon ID code for your species, a source as "source,subsource" choosing from (NCBI, JGI, ENSEMBL, EuPathDB or OTHER) e.g. "JGI,Mycocosm", a 'type' suggesting where your data is predicted from (e.g. DNA, RNA, EST) and a version number (always "1" if you leave this option blank). You may also like to add publication info as a PubMed ID or DOI or simply "YES","NO" or "NA".

#### Any Other Genome Portal
Headers must be plain, consisting of only the accession number:
 * \>Hypho2016_00017489
```
./bin/plant --populate \  # instruct script to add data
            --user test \ # username for OrchardDB
            --pass test \ # password for OrchardDB 
            --db cider \  # OrchardDB name
            --fasta testing/other/richardslab/Hyphochytrium_catenoides_predicted_proteins_renamed_modified.fasta \
            --taxid 42384 \ # NCBI TaxonID
            --source other,richardslab \ # source,subsource
            --type DNA \    # DNA, RNA, EST
            --ver 1 \       # version number
            --pub yes       # yes, DOI, NA
```

#### NCBI Portal
Headers must be in one of these styles, old NCBI or newer:
 * \>gi|CCI39445.1|embl|CCI39445.1| unnamed protein product [Albugo candida]
   * A warning will be issued to update your source.
 * \>6FAI_A unnamed protein product [Saccharomyces cerevisiae S288C]
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/NCBI/Albugo_candida.fas --taxid 65357 --source NCBI --type DNA  --ver 1
./bin/plant --populate --user test --pass test --db cider --fasta testing/NCBI/Saccharomyces_cerevisiae_S288C.fas --taxid 559292 --source NCBI --type DNA  --ver 1 --pub yes
```

#### JGI Genome Portals
##### Mycocosm / Fungi
Headers are usually in this form:
 * \>jgi|Encro1|1|EROM_010010m.01
##### Phytozome & Other -zomes
Headers are usually in this form:
 * \>28448 pacid=27412865 transcript=28448 locus=eugene.1800010031 ID=28448.2.0.231 annot-version=v2.0
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/JGI/Mycocosm/Encro1_GeneCatalog_proteins_20131209.aa.fasta --taxid 1178016 --source JGI,mycocosm --type DNA  --ver 1 --pub yes
./bin/plant --populate --user test --pass test --db cider --fasta testing/JGI/Phytozome/Olucimarinus_231_v2.0.protein.fa --taxid 242159 --source JGI,Phytozome --type DNA  --ver 1 --pub yes
```

#### Ensembl Genome Portals
Headers are usually in this form:
 * \>AAC73113 pep chromosome:ASM584v2:Chromosome:337:2799:1 gene:b0002 transcript:AAC73113 gene_biotype:protein_coding transcript_biotype:protein_coding gene_symbol:thrA description:Bifunctional aspartokinase/homoserine dehydrogenase 1
 * \>EER13651 pep supercontig:JCVI_PMG_1.0:scf_1104296941456:1766:4237:1 gene:Pmar_PMAR004773 transcript:EER13651 gene_biotype:protein_coding transcript_biotype:protein_coding description:cell division protein FtsH, putative
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/Ensembl/Bacteria/Escherichia_coli_str_k_12_substr_mg1655.ASM584v2.pep.all.fa --taxid 83333 --source Ensembl,Bacteria --type DNA  --ver 1 -pub yes
./bin/plant --populate --user test --pass test --db cider --fasta testing/Ensembl/Protists/Perkinsus_marinus_atcc_50983.JCVI_PMG_1.0.pep.all.fa --taxid 423536 --source Ensembl,Protists --type DNA  --ver 1 -pub yes
```

#### EuPathDB Portals
Headers are usually in this form:
 * \>AEWD_010010-t26_1-p1 | transcript=AEWD_010010-t26_1 | gene=AEWD_010010 | organism=Encephalitozoon_cuniculi_EC1 | gene_product=serine hydroxymethyltransferase | transcript_product=serine hydroxymethyltransferase | location=ECI_CH01:23-1405(+) | protein_length=460 | sequence_SO=chromosome | SO
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/EuPathDB/MicrosporidiaDB/MicrosporidiaDB-36_EcuniculiEC1_AnnotatedProteins.fasta --taxid 986730 --source EuPathDB,MicrosporidiaDB --type DNA  --ver 1 -pub yes
```