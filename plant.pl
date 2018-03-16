#!/usr/bin/env perl

use strict;
use warnings;

use Cwd;

use Bio::DB::Taxonomy;
use Bio::SeqIO::fasta;
use Bio::SeqIO;
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

my $VERSION = "OrchardDB v1.0\n--plant.pl v0.1";

# things
my $work_dir = cwd();

# input directories etc
my $input_fasta_dir;     # original FASTA format protein directory
my $output_fasta_dir;    # modified FASTA format protein directory
my $taxadb_dir;          # location of the NCBI taxadb files
my $ncbi_taxid_file;

# database access
my $ip_address = "";
my $dsn        = "dbi:mysql:orchardDB:$ip_address";
my $user;
my $password;
my $table_name;

unless (@ARGV) {
    help_message();
}

GetOptions(
    'in=s'      => \$input_fasta_dir,
    'out=s'     => \$output_fasta_dir,
    'ncbi=s'    => \$ncbi_taxid_file,
    'ip|i=s'    => \$ip_address,
    'user|u=s'  => \$user,
    'pass|p=s'  => \$password,
    'table|t=s' => \$table_name,
    'version|v' => sub { say "$VERSION" },
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
    my @parts     = split( /\//, $file_path );
    my $source    = $parts[1];
    my $subsource = $parts[1];
    my $filename  = $parts[2];
    if ( $source ne "NCBI" ) {
        $subsource = $parts[2];
        $filename  = $parts[3];
    }

    # check if a file in gzip, if so
    # we need to unzip it and update file_path
    if ( $filename =~ /\.gz$/ ) {
        $filename =~ s/\.gz$//;
        say "\tUnzipping: $filename";
        my $status = gunzip "$abs_path" => "$filename"
            or die "gunzip failed: $GunzipError\n";
        $file_path =~ s/\.gz//;
    }

    # set up the output path which will be in the
    # directory one up from the absolute path given
    # by the input directory and named by the user input
    my @dir         = split( $input_fasta_dir, $abs_path );
    my $input_path  = "$dir[0]";
    my $output_path = "$dir[0]$output_fasta_dir";

    ## Process fasta files
    # read in the original file and process it to have
    # new headers and output in the output folder
    say "Reading: $file_path";
    my $seqio_process = open_seqio($file_path);
    process_fasta( $seqio_process, $output_path, $filename );

    ## Get and convert taxids to taxonomy
    #
    get_taxonomy( $filename, @ncbi_taxids, );

    ## Construct MySQL input

    # date time values in 'YYYY-MM-DD HH:MM:SS'
    my $date_time = DateTime->now( time_zone => "local" )->datetime();

    # Remove the erroneous T - not good for MYSQL
    $date_time =~ s/T/ /igs;

    #
    my $seqio_mysql = open_seqio($file_path);
    if ( $source =~ /JGI/i ) {
        process_JGI( $seqio_mysql, $source, $subsource, $filename,
            $date_time );
    }
    elsif ( $source =~ /NCBI/i ) {

    }
    elsif ( $source =~ /Ensembl/i ) {

    }
    elsif ( $source =~ /EuPathDB/i ) {

    }

    # other
    else {

    }

    # gzip

}

########################
##        SUBS        ##
########################

# takes bioperl seqio object, along with
sub process_JGI {
    my ( $seqio_object, $source, $subsource, $filename, $date_time ) = @_;
    my $accession;

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . " " . $seq->desc;

        # different JGI portals have different headers
        # some of fungi may also break here
        if ( $subsource =~ /fungi|mycocosm/i ) {

            # jgi|Encro1|1|EROM_010010m.01
            $original_header =~ /jgi\|.*\|(\d+)\|.*/;
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
    my ( $seqio_object, $output_path, $filename ) = @_;

    # make the output directory if it doesn't exist already
    if ( !-d $output_path ) { make_path($output_path) }

    ###
    # This will come from the input filename list soon...
    my ( $name, $path, $suffix ) = fileparse( $filename, '\.*' );
    say "Output: $output_path\/$name\.fasta";
    ###

    my $output = Bio::SeqIO->new(
        -file   => ">$output_path\/$name\.fasta",
        -format => 'fasta'
    );

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . " " . $seq->desc;
        my $sequence        = $seq->seq;

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);
        $seq->id("$hashed_accession");

        # remove non-useful phylogenetic information from sequence data
        # stop codons at the end of the sequence
        $sequence =~ s/\*$//;

        # replace with X if not a valid protein code
        $sequence =~ s/[^A-z|^\-]/X/g;
        $seq->seq("$sequence");

        $output->write_seq($seq);
    }
}

sub get_taxonomy {
    my ( $filename, @ncbi_taxid_file ) = @_;

    my ($match) = grep { $_ =~ $filename } @ncbi_taxid_file;
    my ( $filenamex, $taxid ) = split( /,/, $match );

    my $db = Bio::DB::Taxonomy->new(
        -source    => 'flatfile',
        -nodesfile => 'nodes.dmp',
        -namesfile => 'names.dmp'
    );

    my $taxon = $db->get_taxon(-taxonid => $taxid);

    say "$taxon - $filename";

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
    my $input_fasta_dir = shift;
    my @fasta_files;
    my $file_finder = sub {
        return if !-f;
        return if !/\.fa|\.fasta|\.fas|\.aa|\.gz\z/;
        push @fasta_files, $File::Find::name;
    };
    find( $file_finder, $input_fasta_dir );
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
    say "Help!";
    exit(1);
}
