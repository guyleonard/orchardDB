#!/usr/bin/env perl

use strict;
use warnings;

use Cwd;
use Bio::DB::Taxonomy;
use Bio::SeqIO::fasta;
use Bio::SeqIO;
use Bio::Tree::Tree;
use DateTime;
use DBD::mysql;
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Find;
use File::Path qw(make_path);
use File::Slurp;
use File::Spec;
use Getopt::Long;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use v5.10;

use Data::Dumper;

our $VERSION = 0.1;
my $version = "OrchardDB v1.0\n--plant.pl v0.1";

# things
my $work_dir = cwd();

# input directories etc
my $input_fasta_dir;     # original FASTA format protein directory
my $output_fasta_dir;    # modified FASTA format protein directory
my $taxadb_dir;          # location of the NCBI taxadb files
my $ncbi_taxid_file;
my $ncbi_taxdump_dir;

# database access
my $ip_address = q{};
my $dsn        = "dbi:mysql:orchardDB:$ip_address";
my $user;
my $password;
my $table_name;

if ( !@ARGV ) {
    help_message();
}

GetOptions(
    'in=s'      => \$input_fasta_dir,
    'out=s'     => \$output_fasta_dir,
    'ncbi=s'    => \$ncbi_taxid_file,
    'dump=s'    => \$ncbi_taxdump_dir,
    'ip|i=s'    => \$ip_address,
    'user|u=s'  => \$user,
    'pass|p=s'  => \$password,
    'table|t=s' => \$table_name,
    'version|v' => sub { say "$version" },
    'help|h'    => sub { help_message() }
) or help_message();

my @fasta_input = get_genome_files($input_fasta_dir);
my @ncbi_taxids = read_file( "$ncbi_taxid_file", chomp => 1 );

########################
##        MAIN        ##
########################

foreach my $file_path (@fasta_input) {

    # find the absolute path for input files, if not specified
    my $abs_path = File::Spec->rel2abs($file_path);

    # extract the directory structure in to source/subsource
    # and filename
    my @parts     = split /\//, $file_path;
    my $source    = $parts[1];
    my $subsource = $parts[1];
    my $filename  = $parts[2];
    if ( $source ne 'NCBI' ) {
        $subsource = $parts[2];
        $filename  = $parts[3];
    }

    # check if a file in gzip, if so
    # we need to unzip it and update file_path
    if ( $filename =~ /[.]gz$/ ) {
        $filename =~ s/[.]gz$//;
        say "Unzipping: $filename";
        my $status = gunzip "$abs_path" => "$filename"
            or die "gunzip failed: $GunzipError\n";
        $file_path =~ s/[.]gz//;
    }

    # set up the output path which will be in the
    # directory one up from the absolute path given
    # by the input directory and named by the user input
    my @dir         = split $input_fasta_dir, $abs_path;
    my $input_path  = "$dir[0]";
    my $output_path = "$dir[0]$output_fasta_dir";

    ## Get and convert taxids to taxonomy
    #
    my ($full_name, $superkingdom, $kingdom, $subkingdom, $phylum,
        $subphylum, $class,        $order,   $family,     $special
    ) = get_taxonomy( $filename, @ncbi_taxids, $ncbi_taxdump_dir );

    ## Process fasta files
    # read in the original file and process it to have
    # new headers and output in the output folder
    say "Reading: $file_path";
    my $seqio_process = open_seqio($file_path);
    process_fasta( $seqio_process, $output_path, $filename, $full_name );

    ## Construct MySQL input

    # date time values in 'YYYY-MM-DD HH:MM:SS'
    my $date_time = DateTime->now( time_zone => 'local' )->datetime();

    # Remove the erroneous T - not good for MYSQL
    $date_time =~ s/T/ /igs;

    #
    my $seqio_mysql = open_seqio($file_path);
    foreach ($source) {
        when ( $source =~ /JGI/i ) {
            process_jgi( $seqio_mysql, $source, $subsource, $filename,
                $date_time );
        }
        when ( $source =~ /NCBI/i ) {

        }
        when ( $source =~ /Ensembl/i ) {

        }
        when ( $source =~ /EuPathDB/i ) {

        }
        default {

        }
    }

    # gzip
}

########################
##        SUBS        ##
########################

# takes bioperl seqio object, along with
sub process_jgi {
    my ( $seqio_object, $source, $subsource, $filename, $date_time ) = @_;
    my $accession;

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;

        # different JGI portals have different headers
        # some of fungi may also break here
        if ( $subsource =~ /fungi|mycocosm/i ) {

            # jgi|Encro1|1|EROM_010010m.01
            $original_header =~ /jgi\[|].*\[|](\d+)\[|].*/;
            $accession = $1;
        }
        elsif ( $subsource =~ /phytozome/i ) {

            #94000 pacid=27412871 transcript=94000 locus=ost_18_004_031 \
            #ID=94000.2.0.231 annot-version=v2.0
            $original_header =~ /\d+\s+pacid\=(\d+)\s+.*/;
            $accession = $1;
        }
        else {
            $accession = $seq->id;
        }

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);
        say
            "$hashed_accession - $accession - $original_header - $date_time - $source - $subsource - $filename";
    }
}

# takes the bioperl seqio object, along with
# the output path and new filename
sub process_fasta {
    my ( $seqio_object, $output_path, $filename, $full_name ) = @_;

    # make the output directory if it doesn't exist already
    if ( !-d $output_path ) { make_path($output_path) }

    # replace spaces with underscores
    $full_name =~ s/\s+/\_/g;

    # replace non-alphanumeric chars with underscore
    # include . and -
    #$full_name =~ s/[^A-z[|]^0-9[|]^\.[|]^\-]/_/g;
    $full_name =~ s/[^\w[|]^[.][|]^\-]/_/g;

    my $output = Bio::SeqIO->new(
        -file   => ">$output_path\/$full_name\.fasta",
        -format => 'fasta'
    );

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;
        my $sequence        = $seq->seq;

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);
        $seq->id("$hashed_accession");

        # remove non-useful phylogenetic information from sequence data
        # stop codons at the end of the sequence
        $sequence =~ s/[*]$//;

        # replace with X if not a valid protein code
        $sequence =~ s/[^A-z|^\-]/X/g;
        $seq->seq("$sequence");

        $output->write_seq($seq);
    }
}

sub get_taxonomy {
    my ( $filename, @ncbi_taxid_file ) = @_;

    my ($match) = grep { $_ =~ $filename } @ncbi_taxid_file;
    my ( $filenamex, $taxid ) = split /,/, $match;

    # if the sqlite db does not exist, warn user
    if ( !-f "$ncbi_taxdump_dir\/taxonomy.sqlite" ) {
        say
            "[INFO]:\tIndexing NCBI Taxonomy - this may take a few minutes on the first run!";
    }

    # read in taxonomy from taxdump
    my $db = Bio::DB::Taxonomy->new(
        -source    => 'sqlite',
        -db        => "$ncbi_taxdump_dir\/taxonomy.sqlite",
        -nodesfile => "$ncbi_taxdump_dir\/nodes.dmp",
        -namesfile => "$ncbi_taxdump_dir\/names.dmp"
    );

    # given the NCBI taxa ID from user input, get the taxon info
    # from the taxdump info
    my $taxon = $db->get_taxon( -taxonid => $taxid );

    # build a bioperl tree
    my $tree_functions = Bio::Tree::Tree->new();

    # get the taxonomy lineage and extract full name
    my $lineage_string = $tree_functions->get_lineage_string($taxon);

    # extract the last element via list splice for taxon full name
    my $full_name = ( split /;/, $lineage_string )[-1];

    # get the taxonomy lineage with associated levels, e.g. Kingdom
    my @lineage_groups = $tree_functions->get_lineage_nodes($taxon);

    my ($superkingdom, $kingdom, $subkingdom, $phylum, $subphylum,
        $class,        $order,   $family,     $special
    ) = qw (X X X X X X X X X);

    foreach my $node (@lineage_groups) {
        if ( $node->rank eq 'superkingdom' ) {
            $superkingdom = $node->node_name;
        }
        if ( $node->rank eq 'kingdom' ) {
            $kingdom = $node->node_name;
        }
        if ( $node->rank eq 'subkingdom' ) {
            $subkingdom = $node->node_name;
        }
        if ( $node->rank eq 'phylum' ) {
            $phylum = $node->node_name;
        }
        if ( $node->rank eq 'subphylum' ) {
            $subphylum = $node->node_name;
        }
        if ( $node->rank eq 'class' ) {
            $class = $node->node_name;
        }
        if ( $node->rank eq 'order' ) {
            $order = $node->node_name;
        }
        if ( $node->rank eq 'family' ) {
            $family = $node->node_name;
        }
        if ( $node->rank eq 'no rank' ) {
            $special = $node->node_name;
        }
    }

    return $full_name, $superkingdom, $kingdom, $subkingdom, $phylum,
        $subphylum, $class, $order, $family, $special;
}

sub open_seqio {
    my $file_path = shift;
    my $seqio_in  = Bio::SeqIO->new(
        -file   => "$file_path",
        -format => 'fasta'
    );
    return $seqio_in;
}

sub get_genome_files {
    my $input_dir = shift;
    my @fasta_files;
    my $file_finder = sub {
        return if !-f;
        return if !/[.]fa[|][.]fasta[|][.]fas[|][.]aa[|][.]gz/;
        push @fasta_files, $File::Find::name;
    };
    find( $file_finder, $input_dir );
    return @fasta_files;
}

# MySQL Database called OrhcardDB, tables are user named
# All DBs include these columns:
# hashed_accession = hash of the header from original file
# original_fn, new_fn = filenames for tracking
# original header
# extracted "accession", e.g. NCBI accessions
# date of inclusion
# version of gene preds if known, else 1
# source DB, e.g. NCBI, JGI_Mycocosm, JGI_Phytozome, Ensenmbl, Other, etc
# taxonomy information
# ????
sub setup_mysql_db {

    my ( $dsn, $user, $password, $table_name ) = @_;

    # connect to MySQL database
    my %attr = ( PrintError => 0, RaiseError => 1 );
    my $dbh = DBI->connect( $dsn, $user, $password, \%attr );

    my $create_table = (
        "CREATE TABLE $table_name (
  hashed_accession varchar(50) NOT NULL DEFAULT '',
  original_fn varchar(50) DEFAULT NULL,
  fixed_fn varchar(50) DEFAULT NULL,
  original_header varchar(200) DEFAULT NULL,
  extracted_accession varchar(20) DEFAULT NULL,
  date_added datetime DEFAULT NULL,
  version text,
  source text,
  taxonomy text,
  PRIMARY KEY (hashed_accession)
  ) ENGINE=InnoDB;"
    );

    $dbh->do($create_table);

    say "$table_name was created successfully!";

    # disconnect from the MySQL database
    $dbh->disconnect();
}

# The idea is that every header will be different, even across
# different taxa, but they are messy and we need a unique ID,
# hashes are perfect for this. They're not human readable, but
# we'll be converting them back to Genus species names anyway.
sub hash_header {
    my $header = shift;
    $header = md5_hex($header);
    return $header;
}

sub help_message {
    say 'Help!';
    exit(1);
}
