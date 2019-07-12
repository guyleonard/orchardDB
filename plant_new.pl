#!/usr/bin/env perl
use strict;
use warnings;

use Bio::DB::Taxonomy;
use DBI;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path);
use Getopt::Long;

use Data::Dumper;

our $VERSION = 0.1;
my $version = "OrchardDB v1.0 -- plant.pl v$VERSION";

#
# Input Variables
#
# database access
my $user;
my $password;
my $db_name;

# options
my $setup;
my $populate;

# inputs
my $fasta_input;
my $taxid;
my $source;
my $type;
my $published = "unknown";
my $data_version;

#
# getopt Logic
#
if ( !@ARGV ) {
    help_message();
}

GetOptions(
    'setup'             => \$setup,
    'populate'          => \$populate,
    'user|u=s'          => \$user,
    'pass|password|p=s' => \$password,
    'db|d=s'            => \$db_name,
    'fasta|f=s'         => \$fasta_input,
    'taxid|t=s'         => \$taxid,
    'source|z=s'        => \$source,
    'type|y=s'          => \$type,
    'pub|p=s'           => \$published,
    'ver|V=s'           => \$data_version,
    'version|v'         => sub { print "$version" },
    'help|h'            => sub { help_message() }
) or help_message();

#
# Main
#
if ($setup) {
    if ( $user && $password && $db_name ) {
        print
            "[OrchardDB:Plant:INFO] - Trying to Create Database $db_name\/$db_name\.sql\n";
        setup_sqlite_db( $user, $password, $db_name );
    }
    else {
        print "[OrchardDB:Plant:ERR] - Missing Input Options\n";
        help_message();
    }
}
elsif ($populate) {
    if (   $user
        && $password
        && $db_name
        && $fasta_input
        && $taxid
        && $source
        && $type
        && $data_version )
    {
        print "[OrchardDB:Plant:INFO] - Here we go!\n";
        my $genome_id
            = generate_genome_ID( $taxid, $data_version, $source, $type );

        my ($genus_species, $lineage) = get_taxonomy("$taxid");
        my @taxon_lineage = @$lineage;

        print "$genome_id\t$genus_species\n@taxon_lineage\n";

    }
    else {
        print "[OrchardDB:Plant:ERR] - Missing Input Options\n";
        help_message();
    }
}

#
# Database Functions
#
sub setup_sqlite_db {
    my ( $user, $password, $db_name ) = @_;

    if ( -f "$db_name\/$db_name\.sql" ) {
        print "[OrchardDB:Plant:INFO] - $db_name\/$db_name\.sql Exists!\n";
    }
    else {

        make_path($db_name);

        my $driver   = "SQLite";
        my $database = "$db_name\/$db_name\.sql";
        my $dsn      = "DBI:$driver:dbname=$database";
        my $dbh = DBI->connect( $dsn, $user, $password, { RaiseError => 1 } )
            or die $DBI::errstr;
        print "[OrchardDB:Plant:INFO] - Successfully Created: $database\n";

        my $main_table = qq(CREATE TABLE odb_maintable(
        genome_id INT PRIMARY KEY NOT NULL,
        original_fn TEXT NOT NULL,
        new_fn TEXT NOT NULL,
        date_added TEXT NOT NULL,
        source TEXT NOT NULL,
        subsource TEXT,
        type TEXT NOT NULL,
        version TEXT NOT NULL,
        ncbi_taxid TEXT NOT NULL,
        published TEXT,
        taxonomy TEXT NOT NULL););

        my $add_main_table = $dbh->do($main_table);
        if ( $add_main_table < 0 ) {
            print "[OrchardDB:Plant:ERROR] - $DBI::errstr\n";
        }
        else {
            print
                "[OrchardDB:Plant:INFO] - Main Table Created Successfully\n";
        }

        my $accession_table = qq(CREATE TABLE odb_accessions(
        hashed_accession CHAR(32) PRIMARY KEY NOT NULL,
        extracted_accession TEXT NOT NULL,
        original_header TEXT NOT NULL,
        lookup_id INT NOT NULL,
        FOREIGN KEY(lookup_id) REFERENCES odb_maintable(genome_id)););

        my $add_accession_table = $dbh->do($accession_table);
        if ( $add_accession_table < 0 ) {
            print "[OrchardDB:Plant:ERROR] - $DBI::errstr\n";
        }
        else {
            print
                "[OrchardDB:Plant:INFO] - Accession Table Created Successfully\n";
        }
        $dbh->disconnect();
    }
}

#
# Genome ID
#
# We need a unique ID for each genome (transciptome etc) entry,
# it cannot be the NCBI TaxID, as we may have both genome/transciptome
# and or multiple versions of a taxa.
# Here we just cat together NCBI TaxID with Version, Source and Type
sub generate_genome_ID {
    my ( $taxid, $data_version, $source, $type ) = @_;
    my $genome_id = create_hash("$taxid$data_version$source$type");
    return $genome_id;
}

#
# Taxonomy
#
sub get_taxonomy {
    my $taxid = shift;
    my $full_name;

    # if the sqlite db does not exist, warn user
    if ( !-f "nodes.dmp" || !-f "names.dmp" ) {
        print
            "[OrchardDB:Plant:WARN] - nodes.dmp and/or names.dmp Missing! Please Download to Continue.\n";
        exit(1);
    }

    if ( !-f "taxonomy.sqlite" ) {
        print "[OrchardDB:Plant:INFO] - Indexing NCBI Taxonomy - Slow!\n";
    }

    # read in taxonomy from taxdump
    my $db = Bio::DB::Taxonomy->new(
        -source    => 'sqlite',
        -db        => "taxonomy.sqlite",
        -nodesfile => "nodes.dmp",
        -namesfile => "names.dmp"
    );

    # given the NCBI taxa ID from user input, get the taxon info
    # from the taxdump info
    my $taxon = $db->get_taxon( -taxonid => $taxid );

    # build a bioperl tree
    my $tree_functions = Bio::Tree::Tree->new();

    # get the taxonomy lineage and extract full name
    my $lineage_string = $tree_functions->get_lineage_string($taxon);

    # extract the last element via list splice for taxon full name
    $full_name = ( split /;/, $lineage_string )[-1];

    # get the taxonomy lineage with associated levels, e.g. Kingdom
    my @lineage_groups = $tree_functions->get_lineage_nodes($taxon);

    return ($full_name, \@lineage_groups);
}

#
# File Functions
#
# MD5 Hash the original sequence header.
# Create a unique header for each sequence that won't break
# downstream phylo programs, but can easily be accessed from the DB.
sub create_hash {
    my $input = shift;
    $input = md5_hex($input);
    return $input;
}

sub process_fasta {
    my ( $db_name, $filename, $genus_species ) = @_;

    if ( !-f "$db_name\/$db_name\.sql" ) {
        print
            "[OrchardDB:Plant:INFO] - No OrchardDB Detected. Please Make a DB First.\n";
    }
    else {
        my $output_path = "$db_name/";

        # replace spaces with underscores
        $genus_species =~ s/\s+/_/g;

        # replace non-alphanumeric chars with underscore
        # include . and - and /
        $genus_species =~ s/[^\w]|\.|\-|\//_/g;

        my $seqio_in = Bio::SeqIO->new(
            -file   => "$filename",
            -format => 'fasta'
        );

        my $seqio_out = Bio::SeqIO->new(
            -file   => ">$output_path\/$genus_species\.fasta",
            -format => 'fasta'
        );

        while ( my $seq = $seqio_in->next_seq() ) {

            # get full header, made from id and description
            my $original_header = $seq->id . ' ' . $seq->desc;
            my $sequence        = $seq->seq;

            # replace header info with a hash
            my $hashed_accession = create_hash($original_header);
            $seq->id("$hashed_accession");

            # remove non-useful phylogenetic information from sequence data
            # stop codons at the end of the sequence
            $sequence =~ s/[*]$//;

            # replace with X if not a valid protein code, not useful in blast
            # or alignments in downstream programs
            $sequence =~ s/[^A-z|^\-]/X/g;
            $seq->seq("$sequence");

            $seqio_out->write_seq($seq);
        }
    }
}

#
# Help Function
#
sub help_message {
    print "Help!\n";
}
