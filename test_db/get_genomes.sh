echo "Downloading Archaeplastida"
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/plants/fasta/arabidopsis_thaliana/pep/Arabidopsis_thaliana.TAIR10.pep.all.fa.gz -a get_archaeplastida.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/plants/fasta/oryza_sativa/pep/Oryza_sativa.IRGSP-1.0.pep.all.fa.gz -a get_archaeplastida.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/plants/fasta/ostreococcus_lucimarinus/pep/Ostreococcus_lucimarinus.ASM9206v1.pep.all.fa.gz -a get_archaeplastida.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/plants/fasta/physcomitrella_patens/pep/Physcomitrella_patens.Phypa_V3.pep.all.fa.gz -a get_archaeplastida.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/plants/fasta/selaginella_moellendorffii/pep/Selaginella_moellendorffii.v1.0.pep.all.fa.gz -a get_archaeplastida.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/plants/fasta/zea_mays/pep/Zea_mays.B73_RefGen_v4.pep.all.fa.gz -a get_archaeplastida.log

echo "Downloading Metazoa"
wget -nc ftp://ftp.ensembl.org/pub/release-97/fasta/ciona_intestinalis/pep/Ciona_intestinalis.KH.pep.all.fa.gz -a get_metazoa.log
wget -nc ftp://ftp.ensembl.org/pub/release-97/fasta/danio_rerio/pep/Danio_rerio.GRCz11.pep.all.fa.gz -a get_metazoa.log
wget -nc ftp://ftp.ensembl.org/pub/release-97/fasta/homo_sapiens/pep/Homo_sapiens.GRCh38.pep.all.fa.gz -a get_metazoa.log
wget -nc ftp://ftp.ensembl.org/pub/release-97/fasta/mus_musculus/pep/Mus_musculus.GRCm38.pep.all.fa.gz -a get_metazoa.log
wget -nc ftp://ftp.ensembl.org/pub/release-97/fasta/takifugu_rubripes/pep/Takifugu_rubripes.FUGU5.pep.all.fa.gz -a get_metazoa.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/metazoa/release-44/fasta/caenorhabditis_elegans/pep/Caenorhabditis_elegans.WBcel235.pep.all.fa.gz -a get_metazoa.log

echo "Downloading Protists"
wget -nc ftp://ftp.ensemblgenomes.org/pub/protists/release-44/fasta/emiliania_huxleyi/pep/Emiliania_huxleyi.Emiliana_huxleyi_CCMP1516_main_genome_assembly_v1.0.pep.all.fa.gz  -a get_protist.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/protists/release-44/fasta/phytophthora_sojae/pep/Phytophthora_sojae.P_sojae_V3_0.pep.all.fa.gz  -a get_protist.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/protists/release-44/fasta/protists_fornicata1_collection/giardia_intestinalis_gca_000498715/pep/Giardia_intestinalis_gca_000498715.ASM49871v1.pep.all.fa.gz  -a get_protist.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/protists/fasta/bigelowiella_natans/pep/Bigelowiella_natans.Bigna1.pep.all.fa.gz  -a get_protist.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/protists/fasta/pythium_ultimum/pep/Pythium_ultimum.pug.pep.all.fa.gz  -a get_protist.log
wget -nc ftp://ftp.ensemblgenomes.org/pub/release-44/protists/fasta/trypanosoma_brucei/pep/Trypanosoma_brucei.TryBru_Apr2005_chr11.pep.all.fa.gz  -a get_protist.log
