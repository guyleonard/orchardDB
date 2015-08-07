# 

## NCBI Protein

### Citations for Style
http://blast.ncbi.nlm.nih.gov/blastcgihelp.shtml
http://www.ncbi.nlm.nih.gov/toolkit/doc/book/ch_demo/?rendertype=table#ch_demo.T5

Not that these are always upheld, but for the most part - especially the sequences returned by scripts in this package - they should all fall in to this same format.

### Real Examples
 * >gi|501172005|ref|WP_012215827.1| abortive infection protein [Nitrosopumilus maritimus]
 * >gi|569442236|gb|ETO37060.1| hypothetical protein RFI_00002 [Reticulomyxa filosa]
 * >gi|67623749|ref|XP_668157.1| dbj|baa86974.1 [Cryptosporidium hominis TU502]

### Archetype

>gi|Genbank Identifier|db|Accession| Other Information
 * gi = GenInfo Integrated Databsae, 2-3 chars, e.g. gi, ref, emb, dbj
 * Genbank Identifier (integer), e.g. 569442236
 * db = Database, 2-3 chars, e.g. gb, ref, emb, dbj
 * Accession, e.g. XP_668157.1
 * Other information includes:
 ** Annotation
 ** Taxa name in []
 ** Junk!

### Regex

```
(>)([A-z]{2,3})(\|)(\d+)(\|)([A-z]{2,3})(\|)(.*)
```
Whilst this regex would work fine, we can 'cheat' and split the line on the '|' character and return positions 2 (GI) and 4 (Accession)

## JGI

### Citations for Style

None that I can find! There appears to be a general consistency across the groups but this is not always upheld. You will notice the frustration this causes below.

### Real Examples

#### Phytozome v10

* >Aquca_023_00143.1 pacid=22022986 transcript=Aquca_023_00143.1 locus=Aquca_023_00143 ID=Aquca_023_00143.1.v1.1 annot-version=v1.1
* >Potri.T155100.2 pacid=26978279 transcript=Potri.T155100.2 locus=Potri.T155100 ID=Potri.T155100.2.v3.0 annot-version=v3.0
* >GRMZM6G175135_P01 pacid=30964399 transcript=GRMZM6G175135_T01 locus=GRMZM6G175135 ID=GRMZM6G175135_T01.v6a annot-version=6a
* >Thhalv10000734m|PACid:20179467

#### Mycocosm

 * >jgi|Schoc1|1|SOCG_02621T0
 * >jgi|Denbi1|748560|estExt_Genewise1Plus.C_390031
 * >jgi|SacceM3838_1|30487|fgenesh1_kg.1_#_5_#_NP_010829.1
 * >jgi|Agabi_varbur_1|123672|Genemark.8_g

#### Others

These are the genomes that don't fall in to the big two JGI genome portals above.

 * >jgi|Auran1|71405
 * >jgi|ChlNC64A_1|18766|e_gw1.1.310.1


#### Metazome v3

This does not seem to be current or kept up-to-date. All the taxa are available from other sources such as NCBI and Ensembl. For the record, Branchiostoma, Hydra and Saccoglossus have different FASTA header lines from the rest.

### Archetype

#### Mycocosm

>jgi|xxxx|xxx|xxx

## UniProt
http://www.uniprot.org/help/fasta-headers