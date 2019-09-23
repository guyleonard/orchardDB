# orchardDB
:apple: :deciduous_tree: A script to create and populate a local database and folder-set of amino acid sequences and taxonomic information retrieved from a variety of genome-portals for use with the Orchard tree building pipeline.

## Installation
Please make sure all dependencies are currently installed, then do:
```
git clone https://github.com/guyleonard/orchardDB.git
```

### Dependencies
#### Perl
```
sudo cpanm Bio::DB::Taxonomy Bio::SeqIO DateTime DBI Digest::MD5 File::Path Getopt::Long

```
#### Database
 * SQLite 3

 e.g.
 ```
 sudo apt-get install sqlite
 ```

#### Databases
 * NCBI Taxdump - from ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
   * Place the names.dmp and nodes.dmp files in to the cloned repository.
   * NCBI's taxonomy is limited and may not acurately reflect current or newly accepted groupings. You can edit it with [this](https://github.com/guyleonard/taxdump_edit) tool.

## Standard Usage
Firstly you must set up a database, and then secondly populate it with sequence data as detailed below.

Amino acid sequences can be derived from DNA or RNA gene predictions, or from EST libraries. Multiple versions of different taxa (e.g. different gene-calling methods or updated genomes) can exist in the database. A unique ID is used to represent the 'genome' in the database and downstream scripts, they can be translated back to a variety of useful information in the orchard package. Additionally, each sequence is given it's own unique ID, separate to that of the one from it's genome portal.

You may add any sequence data you like to your local database, please remember to respect any specific data release policies. Genomes included in the 'testing' dataset and the 'default' *cider* DB are all publically available and published. The majority are sourced from ENSEMBL, JGI and NCBI respectively.

### 'Cider' Database
A set of genomes curated from groups such as Archaeplastida, Fungi, Metazoa, Protists along with Archaea & Bacteria. The list included here is somewhat protist- and fungal-heavy due to the interests of the Richards' Lab. Please add or remove genomes as *your* analyses require. If there are genomes that you have think I have absolutely missed and would like included here, then please feel free to add them by way of a pull-request or add an issue above.

 * ~150 Archaeplastida Genomes
   * A wide selection of Angiosperms from Ensemble Plants, JGI Phytozome, NCBI and others.
   * As many non-angiosperm (Glauco-, Rhodo-, Chloro-phyta) genomes with predicted proteins as I could locate as of July 2019.
   * real   187m47.410s
   * user  45m37.288s
   * sys   17m46.896s
 * Fungal Genomes
   * Coming Soon!
 * ~270 Metazoan Genomes
   * Mostly from Ensembl Metazoa & Vetebrates.
   * Some NCBI and other sources.
   * real  229m2.717s
   * user  67m45.328s
   * sys   21m55.732s
 * Protist Genomes
   * Mostly Ensembl Protists
   * A few from NCBI, EuPathDB and other sources.
   * real  79m26.976s
   * user  25m25.884s
   * sys   7m17.596s
 * Archaea 
   * NCBI's representative set of complete genomes [here](https://www.ncbi.nlm.nih.gov/genome/browse#!/prokaryotes/refseq_category:representative)
 * Bacteria
   * NCBI's reference set of complete genomes [here](https://www.ncbi.nlm.nih.gov/genome/browse#!/prokaryotes/refseq_category:reference)


real  587m34.362s
user  779m50.184s
sys   67m25.940s

#### Set Up *cider* Database
Run the main script in the cider_db folder as below, it will download the initial set of genomes for each group, along with the NCBI taxdump files, and then set up and add them to a local database. The script will not download genomes from JGI due to the user needing to login. You can try [this](https://github.com/guyleonard/get_jgi_genomes) tool to download them, or try to download them via "Globus" or one of the other difficult JGI methods. Place them in the folder prior to running the script.
```
./create_cider_db.sh username password db_name
```

### Your Own Database
#### Set Up
This command will create a directory named "cider" and a SQL DB named "cider.sqlite" in the same directory. This will be your store of information for the whole orchardDB.
```
./bin/plant --setup \     # instruct script to create OrchardDB
            --user test \ # username for OrchardDB
            --pass test \ # password for OrchardDB 
            --db cider    # OrchardDB name
```

#### Populate Database
This command will add information to the database and copy your original files to the database directory with the new headers. You will need to provide a file of your amino acids in FASTA format, an NCBI Taxon ID code for your species, a source as "source,subsource" choosing from (NCBI, JGI, ENSEMBL, EuPathDB or OTHER) e.g. "JGI,Mycocosm", a 'type' suggesting where your data is predicted from (e.g. DNA, RNA, EST) and a version number (always "1" if you leave this option blank). You may also like to add publication info as a PubMed ID or DOI or simply "YES","NO" or "NA". You may choose to store sequences in the DB by using the "lite" option, however this is not standard and is turned off by default (reduces DB size).

##### Any Other Genome Portal
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
            --pub PMID:29321239  # yes, PMID, DOI, NA
            --lite T        # store sequence in DB T/F?
```

##### NCBI Portal
Headers must be in one of these styles, old NCBI or newer:
 * \>gi|CCI39445.1|embl|CCI39445.1| unnamed protein product [Albugo candida]
   * A warning will be issued to update your source.
 * \>6FAI_A unnamed protein product [Saccharomyces cerevisiae S288C]
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/NCBI/Albugo_candida.fas --taxid 65357 --source NCBI --type DNA  --ver 1
./bin/plant --populate --user test --pass test --db cider --fasta testing/NCBI/Saccharomyces_cerevisiae_S288C.fas --taxid 559292 --source NCBI --type DNA  --ver 1 --pub yes
```

##### JGI Genome Portals
###### Mycocosm / Fungi
Headers are usually in this form:
 * \>jgi|Encro1|1|EROM_010010m.01
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/JGI/Mycocosm/Encro1_GeneCatalog_proteins_20131209.aa.fasta --taxid 1178016 --source JGI,mycocosm --type DNA  --ver 1 --pub yes
```

###### Phytozome & Other -zomes
Headers are usually in this form:
 * \>28448 pacid=27412865 transcript=28448 locus=eugene.1800010031 ID=28448.2.0.231 annot-version=v2.0
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/JGI/Phytozome/Olucimarinus_231_v2.0.protein.fa --taxid 242159 --source JGI,Phytozome --type DNA  --ver 1 --pub yes
```

##### Ensembl Genome Portals
Headers are usually in this form:
 * \>AAC73113 pep chromosome:ASM584v2:Chromosome:337:2799:1 gene:b0002 transcript:AAC73113 gene_biotype:protein_coding transcript_biotype:protein_coding gene_symbol:thrA description:Bifunctional aspartokinase/homoserine dehydrogenase 1
 * \>EER13651 pep supercontig:JCVI_PMG_1.0:scf_1104296941456:1766:4237:1 gene:Pmar_PMAR004773 transcript:EER13651 gene_biotype:protein_coding transcript_biotype:protein_coding description:cell division protein FtsH, putative
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/Ensembl/Bacteria/Escherichia_coli_str_k_12_substr_mg1655.ASM584v2.pep.all.fa --taxid 83333 --source Ensembl,Bacteria --type DNA  --ver 1 -pub yes
```
or
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/Ensembl/Protists/Perkinsus_marinus_atcc_50983.JCVI_PMG_1.0.pep.all.fa --taxid 423536 --source Ensembl,Protists --type DNA  --ver 1 -pub yes
```

##### EuPathDB Portals
Headers are usually in this form:
 * \>AEWD_010010-t26_1-p1 | transcript=AEWD_010010-t26_1 | gene=AEWD_010010 | organism=Encephalitozoon_cuniculi_EC1 | gene_product=serine hydroxymethyltransferase | transcript_product=serine hydroxymethyltransferase | location=ECI_CH01:23-1405(+) | protein_length=460 | sequence_SO=chromosome | SO
```
./bin/plant --populate --user test --pass test --db cider --fasta testing/EuPathDB/MicrosporidiaDB/MicrosporidiaDB-36_EcuniculiEC1_AnnotatedProteins.fasta --taxid 986730 --source EuPathDB,MicrosporidiaDB --type DNA  --ver 1 -pub yes
```

#### Remove Taxa from Database
Sometimes you may wish to delete a taxa and all it's associated records from the DB. You can do this with the "uproot" command and the unique genome ID of your taxa.

```
./bin/plant --uproot 01bd3bdf0e8ae98c26aec99074fefaab \ # genome ID
            --user test \
            --pass test \
            --db cider
```

### Other Scripts
#### catalogue
This script will query your database and output a tab-separated text file of the main database table. This allows the user to see the IDs that were generated for each of their 'genomes' in the database along with the other information stored there. This is useful for choosing the taxa that you want to use in the 'Orchard' scripts.
```
./bin/catalogue username password /path/to/database.sql
```
