# orchardDB
:apple: :deciduous_tree: A script to create and populate a local database of amino acid sequences combined with taxonomic information, the AA gene predictions can be retrieved from a variety of genome-portals and then used with the [Orchard tree building pipeline](https://github.com/guyleonard/orchard).

## Installation
Please make sure all dependencies are currently installed, then do:
```
git clone https://github.com/guyleonard/orchardDB.git
```

### Dependencies
#### Perl
If you have 'cpan minus' installed you can simply do:
```
sudo cpanm Bio::DB::Taxonomy Bio::SeqIO DateTime DBI Digest::MD5 File::Path Getopt::Long
```

To install 'cpan minus' on Ubuntu:
```
 sudo apt install cpanminus
```

#### Database
 * SQLite 3
 To install 'sqlite' on Ubuntu:
 ```
 sudo apt install sqlite
 ```

#### NCBI's Taxonmomic Database
 * NCBI Taxdump - from ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
   * Place the names.dmp and nodes.dmp files in to the cloned repository.

NB - NCBI's taxonomy can be limited and may not acurately reflect current or newly accepted groups/clades. You can edit it with [this](https://github.com/guyleonard/taxdump_edit) tool.

## Standard Usage
Firstly you must set up a database, and then secondly populate it with sequence data as detailed below.

Amino acid sequences can be derived from the gene predictions of DNA or RNA-Seq assemblies, or from EST libraries. Multiple versions of different taxa (e.g. different gene-calling methods or updated genome versions) can exist in the same database. A unique ID is used to represent the 'genome' in this database, and in downstream scripts/data files, they can be translated back to a variety of useful information via the tools in the Orchard pipeline. Additionally, each sequence itself is given it's own unique ID, separate to that of the one from the originating genome portal. These IDs will be the same across multiple versions of databases, assuming the same source files are used to build them.

You may add any sequence data you like to your local database, please remember to respect any specific data release policies that they may be bound by. Genomes included in the 'testing' dataset are all publically available and published.

### Your Own Data
Here you will learn how to set up your own database. First you need to create the database directory and 'sql' schema - don't worry, there's a script to do this for you, all you need to do is choose a name, username and password. Following that, you will need to populate your database.

#### Set Up
This command will create a directory named "example" and a SQL DB named "example.sqlite" in the same directory. This will be your store of information for the whole of your orchardDB.
```
./bin/plant --setup \       # instruct script to create OrchardDB
            --user test \   # username for OrchardDB
            --pass test \   # password for OrchardDB 
            --db example    # OrchardDB name
```

#### Populate Database
This command will add information to the database, and copy your original files to the database directory with the new header IDs. You will need to provide a file of your amino acids in FASTA format, an NCBI Taxon ID code for your taxa, a source written as "source,subsource" choosing from (NCBI, JGI, ENSEMBL, EuPathDB or OTHER) e.g. "JGI,Mycocosm", a 'type' suggesting where your data is predicted from (e.g. DNA, RNA, EST) and a version number (default "1"). You may also like to add a publication as a PubMed ID or DOI. You may also choose to store sequences in the DB by using the "lite" option, however this is not standard and is turned off by default (reduces DB size).

##### 'Yet Another Genome Portal' aka Your Own Data
Headers must be plain, consisting of only the accession number:
 * \>Hypho2016_00017489
```
./bin/plant --populate \          # instruct script to add data
            --user test \         # username for OrchardDB
            --pass test \         # password for OrchardDB 
            --db example \        # OrchardDB name
            --fasta input.fasta \ # input file name
            --taxid 42384 \       # NCBI TaxonID
            --source other,guy \  # source,subsource
            --type DNA \          # DNA, RNA, EST
            --ver 1 \             # version number
            --pub PMID:29321239   # yes, PMID, DOI, NA
            --lite T              # store sequence in DB T=no/F=yes
```

## Header Formats
The input FASTA files will need to have their accession/information headers be in one of the standard formats as below, database inseration examples are also given.

### NCBI
Headers must be in one of these styles, old NCBI or newer:
 * \>gi|CCI39445.1|embl|CCI39445.1| unnamed protein product [Albugo candida]
   * A warning will be issued to update your source as this is an older format, pre 2018.
 * \>6FAI_A unnamed protein product [Saccharomyces cerevisiae S288C]
```
./bin/plant --populate --user test --pass test --db example --fasta testing/NCBI/Albugo_candida.fas --taxid 65357 --source NCBI --type DNA  --ver 1
./bin/plant --populate --user test --pass test --db example --fasta testing/NCBI/Saccharomyces_cerevisiae_S288C.fas --taxid 559292 --source NCBI --type DNA  --ver 1 --pub yes
```

### JGI Mycocosm - Fungi & Phycocosm
Headers must be in this format:
 * \>jgi|Encro1|1|EROM_010010m.01
```
./bin/plant --populate --user test --pass test --db example --fasta testing/JGI/Mycocosm/Encro1_GeneCatalog_proteins_20131209.aa.fasta --taxid 1178016 --source JGI,mycocosm --type DNA  --ver 1 --pub yes
```

### JGI Phytozome & Metazome
Headers must be in this format:
 * \>28448 pacid=27412865 transcript=28448 locus=eugene.1800010031 ID=28448.2.0.231 annot-version=v2.0
```
./bin/plant --populate --user test --pass test --db example --fasta testing/JGI/Phytozome/Olucimarinus_231_v2.0.protein.fa --taxid 242159 --source JGI,Phytozome --type DNA  --ver 1 --pub yes
```

### Ensembl Genome Portals
Headers must be in this format:
 * \>AAC73113 pep chromosome:ASM584v2:Chromosome:337:2799:1 gene:b0002 transcript:AAC73113 gene_biotype:protein_coding transcript_biotype:protein_coding gene_symbol:thrA description:Bifunctional aspartokinase/homoserine dehydrogenase 1
 * \>EER13651 pep supercontig:JCVI_PMG_1.0:scf_1104296941456:1766:4237:1 gene:Pmar_PMAR004773 transcript:EER13651 gene_biotype:protein_coding transcript_biotype:protein_coding description:cell division protein FtsH, putative
```
./bin/plant --populate --user test --pass test --db example --fasta testing/Ensembl/Bacteria/Escherichia_coli_str_k_12_substr_mg1655.ASM584v2.pep.all.fa --taxid 83333 --source Ensembl,Bacteria --type DNA  --ver 1 -pub yes
```
or
```
./bin/plant --populate --user test --pass test --db example --fasta testing/Ensembl/Protists/Perkinsus_marinus_atcc_50983.JCVI_PMG_1.0.pep.all.fa --taxid 423536 --source Ensembl,Protists --type DNA  --ver 1 -pub yes
```

### EuPathDB Family Portals
Headers must be in this format:
 * \>AEWD_010010-t26_1-p1 | transcript=AEWD_010010-t26_1 | gene=AEWD_010010 | organism=Encephalitozoon_cuniculi_EC1 | gene_product=serine hydroxymethyltransferase | transcript_product=serine hydroxymethyltransferase | location=ECI_CH01:23-1405(+) | protein_length=460 | sequence_SO=chromosome | SO
```
./bin/plant --populate --user test --pass test --db example --fasta testing/EuPathDB/MicrosporidiaDB/MicrosporidiaDB-36_EcuniculiEC1_AnnotatedProteins.fasta --taxid 986730 --source EuPathDB,MicrosporidiaDB --type DNA  --ver 1 -pub yes
```

### Ensembl Protists
For example, you may wish to use just the Ensembl Protist dataset. To do this:
 * coming soon

### JGI Phycocosm
For example, you may wish to use just the Ensembl Protist dataset. To do this:
 * coming soon

### Removing Taxa from a Database
Sometimes you may wish to delete an old taxa along with all associated records from the DB. You can do this with the "uproot" command and the unique genome ID of your taxa.

```
./bin/plant --uproot 01bd3bdf0e8ae98c26aec99074fefaab \ # genome ID
            --user test \
            --pass test \
            --db example
```

### Other Scripts
#### catalogue
This script will query your database and output a tab-separated text file of the main database table. This allows the user to see the IDs that were generated for each of their 'genomes' in the database along with the other information stored there. This is useful for choosing the taxa that you want to use in the 'Orchard' scripts.
```
./bin/catalogue username password /path/to/database.sql
```
