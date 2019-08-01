../bin/plant --setup --user test --pass test --db cider    

../bin/plant --populate --user test --pass test --db cider --fasta other/richardslab/Hyphochytrium_catenoides_predicted_proteins_renamed_modified.fasta --taxid 42384 --source other,richardslab --type DNA --ver 1 --pub yes       

../bin/plant --populate --user test --pass test --db cider --fasta NCBI/Albugo_candida.fas --taxid 65357 --source NCBI --type DNA  --ver 1
../bin/plant --populate --user test --pass test --db cider --fasta NCBI/Saccharomyces_cerevisiae_S288C.fas --taxid 559292 --source NCBI --type DNA  --ver 1 --pub yes

../bin/plant --populate --user test --pass test --db cider --fasta JGI/Mycocosm/Encro1_GeneCatalog_proteins_20131209.aa.fasta --taxid 1178016 --source JGI,mycocosm --type DNA  --ver 1 --pub yes
../bin/plant --populate --user test --pass test --db cider --fasta JGI/Phytozome/Olucimarinus_231_v2.0.protein.fa --taxid 242159 --source JGI,Phytozome --type DNA  --ver 1 --pub yes

../bin/plant --populate --user test --pass test --db cider --fasta Ensembl/Bacteria/Escherichia_coli_str_k_12_substr_mg1655.ASM584v2.pep.all.fa --taxid 83333 --source Ensembl,Bacteria --type DNA  --ver 1 -pub yes
../bin/plant --populate --user test --pass test --db cider --fasta Ensembl/Protists/Perkinsus_marinus_atcc_50983.JCVI_PMG_1.0.pep.all.fa --taxid 423536 --source Ensembl,Protists --type DNA  --ver 1 -pub yes

../bin/plant --populate --user test --pass test --db cider --fasta EuPathDB/MicrosporidiaDB/MicrosporidiaDB-36_EcuniculiEC1_AnnotatedProteins.fasta --taxid 986730 --source EuPathDB,MicrosporidiaDB --type DNA  --ver 1 -pub yes
