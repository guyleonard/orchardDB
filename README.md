# orchardDB
:apple: :deciduous_tree: The orchardDB suite of tools takes a set of user collated amino acid gene predictions in FASTA format from different taxa and/or assemblies and builds a local SQLITE database and data folder of consistently, repeatable and uniquely re-named accessions ready to be used with the [Orchard tree building pipeline](https://github.com/guyleonard/orchard) or other downstream applications. The SQLITE database allows for fast access to metadata in order to annotate taxonomy (via NCBI Taxonomy) and other information into alignments and trees.

Below you will find a set of instructions to install the scripts & dependencies and also how to build your first database. There are also instructions to import datasets from genome portals such as Ensembl, JGI and EukProt.

## Standard Usage
Firstly you will need collate your set of input sequences, secondly to set up a database, and then thirdly populate the database with sequence data as detailed below.

Amino acid sequences can be derived from the gene predictions of DNA or RNA-Seq assemblies, or from EST libraries. Multiple versions of different taxa (e.g. different gene-calling methods or updated genome versions) can exist in the same database. A unique ID is used to represent the 'genome' in the database, and also in downstream scripts/data files, they can be translated back to a variety of useful information via the tools in the Orchard pipeline. Additionally, each sequence itself is given it's own unique ID, separate to that of the one from the originating genome portal. These IDs will be the same across multiple versions of databases, assuming the same source files are used to build them.

You may add any sequence data you like to your local database, please remember to respect any specific data release policies that they may be bound by. Genomes included in the 'testing' dataset are all publically available and published.

### Using Your Own Data
Here you will learn how to set up your own database. First you need to create the database directory and 'sql' schema - don't worry, there's a script to do this for you, all you need to do is choose a name, username and password. Following that, you will need to populate your database.

#### Set Up
This command will create a directory named "example" and a SQL DB named "example.sqlite" in the same directory. This will be your store of information for the whole of your orchardDB.
```
./bin/plant --setup \       # instruct script to create an OrchardDB
            --user test \   # username for OrchardDB
            --pass test \   # password for OrchardDB 
            --db example    # OrchardDB name
```

#### Populate Database
This command will add information to the database, and copy your original files to the database directory with the new header IDs. You will need to provide a file of your amino acids in FASTA format, an NCBI Taxon ID code for your taxa, a source written as "source,subsource" choosing from (NCBI, JGI, ENSEMBL, EuPathDB or OTHER) e.g. "JGI,Mycocosm", a 'type' suggesting where your data is predicted from (e.g. DNA, RNA, EST) and a version number (default "1"). You may also like to add a publication as a PubMed ID or DOI. You may also choose to store sequences in the DB by using the "lite" option, however this is not standard and is turned off by default (reduces DB size).

#### 'Yet Another Genome Portal' aka Your Own Data
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

### Ensembl Protists
 * coming soon

### JGI Phycocosm
 * coming soon

### EukProt
 * coming soon

## Other Scripts / Commands

### Removing Taxa from a Database
Sometimes you may wish to delete an old taxa along with all associated records from the DB. You can do this with the "uproot" command and the unique genome ID of your taxa.

```
./bin/plant --uproot 01bd3bdf0e8ae98c26aec99074fefaab \ # genome ID
            --user test \
            --pass test \
            --db example
```

Warning: This will mean that any downstream files (e.g. phylogenies) that you have not translated from orchardDB IDs to taxonomic names that include the removed taxa will not be able to be translated.

### catalogue
This script will query your database and output a tab-separated text file of the main database table. This allows the user to see the IDs that were generated for each of their 'genomes' in the database along with the other information stored there. This is useful for choosing the taxa that you want to use in the 'Orchard' scripts.
```
./bin/catalogue username password /path/to/database.sql
```

## Installation
Please make sure all dependencies are installed, then clone the repository:
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

## Internal Taxa and Accession Names
This database is mainly intended for use with the Orchard Tree Building pipeline or for producing your own phylogenies. Some issues that affect leaf-naming within treefiles are their length (although not a huge constraint more recently), the use of non-alphanumeric characters (which interfere with Newick/Nexus formats) and identidical accessions even though they may come from different gene prediction sets or taxa. Another issue that you may experience in your database creation is providing gene predictions for the same taxa but from different versions or different assemblies. This can lead to identicial file names or filenames that end up looking something like "taxa_name_version_2_1_updated_final" or similar.

In order to address this, the orchardDB script translates the names into it's own consistent and unique identities. We do this by providing some of the information to a 'hashing' function (specifically MD5). This means that the files and accessions end up being unreadable in a human-way, but for the most part we don't need to know what files we are dealing with - just the scripts do, and tools are provided to translate the names back later (this is the current reason for use of the SQL database).

### Filenames
To generate a consistent and unique taxonomic ID within the database for each input, we take the NCBI:txid, the version number of the predictions, the source, and the 'type' of data.

For example, the input of;

 * TaxID: 1313167
 * Version: 2018
 * Souce: other,richardslab
 * Type: DNA

Produces: 0e69f6622affb742c678ab46cf7d1302

Modifying any of the input variables by even one letter will change the hashed output name, so this gives the user multiple ways to include either different gene prediction versions, different sources or different types of the same taxa in the database.

### Accessions
The accessions are handled in a similar way, although

For example, the input of;
  
 * accession: FUN_000001-T1 FUN_000001
 * genome_ID: 0e69f6622affb742c678ab46cf7d1302

Produces: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

## A Note on Input Header Formats
As well as the ability to import data with just an accession (as in the YAGP example above) the input FASTA files can have their accession/information headers be in one of the standard formats as below, here we provide database inseration examples too.

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