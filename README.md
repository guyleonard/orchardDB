# orchardDB
:apple: :deciduous_tree: A set of publicly available amino acid sequences from various genome portals and projects for use with the Orchard pipeline.


## Dependencies
### Perl
 * Bioperl
 * DateTime
 * Bio::DB::Taxonomy;
 * Bio::SeqIO;
 * DBI;
 * Digest::MD5 qw(md5_hex);
 * File::Path qw(make_path);
 * Getopt::Long; 
```
  sudo cpanm Bio::Perl DateTime
```
### System Tools
 * SQLite 3

## Usage
### Setup
```
  plant_new.pl --setup --user test --pass test --db cider
```
