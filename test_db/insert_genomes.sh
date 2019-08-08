USER=$1
PASS=$2
DB=$3

../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Arabidopsis_thaliana.TAIR10.pep.all.fa --taxid 3702 --source Ensembl,Plants --type DNA --ver TAIR10 --pub DOI:10.1038/35048692 --lite T
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Oryza_sativa.IRGSP-1.0.pep.all.fa --taxid 39947 --source Ensembl,Plants --type DNA --ver IRGSP-1.0 --pub DOI:10.1126/science.1068037 --lite T
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Ostreococcus_lucimarinus.ASM9206v1.pep.all.fa --taxid 436017 --source Ensembl,Plants --type DNA --ver ASM9206v1 --pub DOI:10.1073/pnas.0611046104 --lite T
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Physcomitrella_patens.Phypa_V3.pep.all.fa --taxid 3218 --source Ensembl,Plants --type DNA --ver v3 --pub DOI:10.1016/j.cell.2017.09.030 --lite T
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Selaginella_moellendorffii.v1.0.pep.all.fa --taxid 88036 --source Ensembl,Plants --type DNA --ver v1.0 --pub DOI:10.1126/science.1203810  --lite T
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Zea_mays.B73_RefGen_v4.pep.all.fa --taxid 4577 --source Ensembl,Plants --type DNA --ver v4 --pub DOI:10.1126/science.1178534 --lite T

../bin/plant --populate --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Caenorhabditis_elegans.WBcel235.pep.all.fa --taxid 6239 --source Ensembl,Metazoa --type DNA --ver WBcel235 --pub NA --lite T
../bin/plant --populate --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Ciona_intestinalis.KH.pep.all.fa --taxid 7719 --source Ensembl,V97 --type DNA --ver KH --pub NA --lite T
../bin/plant --populate --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Danio_rerio.GRCz11.pep.all.fa --taxid 7955 --source Ensembl,V97 --type DNA --ver GRCz11 --pub NA --lite T
../bin/plant --populate --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Homo_sapiens.GRCh38.pep.all.fa --taxid 9606 --source Ensembl,V97 --type DNA --ver GRCh38.p12 --pub NA --lite T
../bin/plant --populate --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Mus_musculus.GRCm38.pep.all.fa --taxid 10090 --source Ensembl,V97 --type DNA --ver GRCm38.p6 --pub NA --lite T
../bin/plant --populate --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Takifugu_rubripes.FUGU5.pep.all.fa --taxid 31033 --source Ensembl,V97 --type DNA --ver FUGU5 --pub NA --lite T

../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Bigelowiella_natans.Bigna1.pep.all.fa --taxid 753081 --source Ensembl,Protists --type DNA --ver Bigna1 --pub NA
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Emiliania_huxleyi.Emiliana_huxleyi_CCMP1516_main_genome_assembly_v1.0.pep.all.fa --taxid 280463 --source Ensembl,Protists --type DNA --ver Emiliana_huxleyi_CCMP1516_main_genome_assembly_v1.0 --pub NA
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Giardia_intestinalis_gca_000498715.ASM49871v1.pep.all.fa --taxid 5741 --source Ensembl,Protists --type DNA --ver ASM49871v1 --pub NA
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Phytophthora_sojae.P_sojae_V3_0.pep.all.fa --taxid 67593 --source Ensembl,Protists --type DNA --ver P_sojae_V3_0 --pub NA
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Pythium_ultimum.pug.pep.all.fa --taxid 431595 --source Ensembl,Protists --type DNA --ver pug --pub NA
../bin/plant --populate  --user ${USER} --pass ${PASS} --db ${DB} --fasta ${DB}/original/Trypanosoma_brucei.TryBru_Apr2005_chr11.pep.all.fa --taxid 5691 --source Ensembl,Protists --type DNA --ver TryBru_Apr2005_chr11 --pub NA
