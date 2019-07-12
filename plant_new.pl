#!/usr/bin/env perl
use strict;
use warnings;

use Bio::DB::Taxonomy;
use Bio::SeqIO;
use DateTime;
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
my $warnings = 1;

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
my $sources;
my $type;
my $published = "NA";
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
    'source|z=s'        => \$sources,
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
        && $sources
        && $type
        && $data_version )
    {
        print "[OrchardDB:Plant:INFO] - And awaaay we go!\n";

        # Generate 'genome_id' record to link database objects
        my $genome_id
            = generate_genome_ID( $taxid, $data_version, $sources, $type );
        print "[OrchardDB:Plant:INFO] - Your GenomeID: $genome_id\n";

        # get the genus+species and BioPerl taxonomy
        my ( $genus_species, $taxon_lineage ) = get_taxonomy("$taxid");

        # get the date time values in 'YYYY-MM-DD HH:MM:SS'
        my $date_time = DateTime->now( time_zone => 'local' )->datetime();

        # Remove the erroneous T - not good for MYSQL
        $date_time =~ s/T/ /igs;

        # get source and subsource
        my ( $source, $subsource );
        if ( $sources =~ m/,/ ) {

            ( $source, $subsource ) = split /,/, $sources;
        }
        else {
            print "[OrchardDB:Plant:WARN] - Setting subsource to: none.\n";
            $source    = $sources;
            $subsource = "none";
        }

        if ($published eq "NA") {
            print "[OrchardDB:Plant:WARN] - Setting published to: NA.\n";
        }

        my $fasta_output = "$genus_species\.fasta";
        $fasta_output =~ s/\s+/_/g;

        print "[OrchardDB:Plant:INFO] - Populating Main Table!\n";
        insert_main_table_record(
            $user,        $password,     $db_name,      $genome_id,
            $fasta_input, $fasta_output, $date_time,    $source,
            $subsource,   $type,         $data_version, $taxid,
            $published,   $taxon_lineage
        );

        my @odb_accessions
            = process_fasta( $db_name, $fasta_input, $genus_species, $source,
            $subsource );

        print "[OrchardDB:Plant:INFO] - Populating Accessions Table!\n";
        insert_accession_records( $user, $password, $db_name, $genome_id,
            @odb_accessions );
    }

    else {
        print "[OrchardDB:Plant:ERRR] - Missing Input Options\n";
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

        my $main_table = qq(CREATE TABLE IF NOT EXISTS odb_maintable(
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

        my $accession_table = qq(CREATE TABLE IF NOT EXISTS odb_accessions(
        hashed_accession TEXT PRIMARY KEY NOT NULL,
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

sub insert_main_table_record {
    my ($user,        $password,     $db_name,      $genome_id,
        $fasta_input, $fasta_output, $date_time,    $source,
        $subsource,   $type,         $data_version, $taxid,
        $published,   $taxon_lineage
    ) = @_;

    if ( !-f "$db_name\/$db_name\.sql" ) {
        print
            "[OrchardDB:Plant:INFO] - $db_name\/$db_name\.sql Does Not Exist!\n";
    }
    else {

        my $driver   = "SQLite";
        my $database = "$db_name\/$db_name\.sql";
        my $dsn      = "DBI:$driver:dbname=$database";
        my $dbh = DBI->connect( $dsn, $user, $password, { RaiseError => 1 } )
            or die $DBI::errstr;
        print "[OrchardDB:Plant:INFO] - Successfully Conected: $database\n";

        my $statement
            = qq (INSERT OR IGNORE INTO odb_maintable (genome_id,original_fn,new_fn,date_added,source,subsource,type,version,ncbi_taxid,published,taxonomy) 
                VALUES (?,?,?,?,?,?,?,?,?,?,?));
        my $prepare = $dbh->prepare($statement);
        my $insert  = $prepare->execute(
            "$genome_id",    "$fasta_input",
            "$fasta_output", "$date_time",
            "$source",       "$subsource",
            "$type",         "$data_version",
            "$taxid",        "$published",
            "$taxon_lineage"
        ) or die $DBI::errstr;

        $dbh->disconnect();
    }
}

sub insert_accession_records {
    my ( $user, $password, $db_name, $genome_id, @odb_accessions ) = @_;

    if ( !-f "$db_name\/$db_name\.sql" ) {
        print
            "[OrchardDB:Plant:INFO] - $db_name\/$db_name\.sql Does Not Exist!\n";
    }
    else {

        my $driver   = "SQLite";
        my $database = "$db_name\/$db_name\.sql";
        my $dsn      = "DBI:$driver:dbname=$database";
        my $dbh = DBI->connect( $dsn, $user, $password, { RaiseError => 1 } )
            or die $DBI::errstr;
        print "[OrchardDB:Plant:INFO] - Successfully Conected: $database\n";

        my $statement
            = qq (INSERT OR IGNORE INTO odb_accessions (hashed_accession,extracted_accession,original_header,lookup_id)
             VALUES (?,?,?,?));
        my $prepare = $dbh->prepare($statement);

        foreach my $sequence (@odb_accessions) {
            my ( $hashed_accession, $accession, $original_header )
                = split /,/,
                $sequence;

            my $insert = $prepare->execute(
                "$hashed_accession", "$accession",
                "$original_header",  "$genome_id"
            ) or die $DBI::errstr;
            print "[OrchardDB:Plant:INFO] - Inserting $accession\n"
                if $warnings == 1;
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

    my $lineages = "";
    foreach my $node (@lineage_groups) {
        my $rank = $node->rank;
        my $name = $node->node_name;
        $lineages = $lineages . "$rank\:$name\;";
    }

    return ( "$full_name", "$lineages" );
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
    my ( $db_name, $filename, $genus_species, $source, $subsource ) = @_;
    my $accession;
    my @odb_accessions;

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

            # output to file
            $seqio_out->write_seq($seq);

            if ( $source =~ m/ncbi/i ) {
                $accession = process_ncbi( $original_header, $subsource );
            }
            elsif ( $source =~ m/jgi/i ) {
                $accession = process_jgi( $original_header, $subsource );
            }
            elsif ( $source =~ m/ensembl/i ) {
                $accession = process_ensembl( $original_header, $subsource );
            }
            elsif ( $source =~ m/eupathdb/i ) {
                $accession = process_eupathdb( $original_header, $subsource );
            }
            else {
                ($accession) = split / /, $original_header;
            }

            # output to array
            push @odb_accessions,
                "$hashed_accession,$accession,$original_header";
        }
    }

    return @odb_accessions;
}

#
# Portal Functions
#
sub process_eupathdb {
    my $header = shift;
    my $accession;

    #AEWD_010030-t26_1-p1 | transcript=AEWD_010030-t26_1 | gene=AEWD_010030 |
    $header =~ /.*gene=(.*)\s+\|\s+org.*/;
    if ( !defined $1 ) {
        $accession = $header;
    }
    else {
        $accession = $1;
    }

    return $accession;
}

sub process_ensembl {
    my $header = shift;
    my $accession;

    #EER13651 pep supercontig:JCVI_PMG_1.0:scf_1104 ...
    $header =~ /(.*)( pep .*)/ig;
    if ( !defined $1 ) {
        $accession = $header;
    }
    else {
        $accession = $1;
    }
    return $accession;
}

sub process_jgi {
    my ( $header, $subsource ) = @_;
    my $accession;

    # each JGI portals has different headers
    # some of the fungi may also break here
    if ( $subsource =~ /fungi|mycocosm/i ) {

        # jgi|Encro1|1|EROM_010010m.01
        $header =~ /jgi[|].*[|](\d+)[|].*/;
        if ( !defined $1 ) {
            $accession = $header;
        }
        else {
            $accession = $1;
        }
    }
    elsif ( $subsource =~ /phytozome/i ) {

        #94000 pacid=27412871 transcript=94000 locus=ost_18_004_031 \
        #ID=94000.2.0.231 annot-version=v2.0
        $header =~ /\d+\s+pacid\=(\d+)\s+.*/;
        if ( !defined $1 ) {
            $accession = $header;
        }
        else {
            $accession = $1;
        }
    }
    else {
        $accession = $header;
    }

    return $accession;
}

sub process_ncbi {
    my $header = shift;
    my $accession;

    if ( $header =~ /^gi/ ) {
        print
            "[OrchardDB:Plant:WARN] - Old Style NCBI Headers Detected. Consider Updating your Source Data.\n"
            if $warnings == 1;
        $header =~ /gi\|.*\|.*\|(.*)\|.*/;
        if ( !defined $1 ) {
            $accession = $header;
        }
        else {
            $accession = $1;
        }
    }
    else {
        ($accession) = split / /, $header;
    }
    return $accession;
}

#
# Help Function
#
sub help_message {
    print "Help!\n";
    exit(1);
}
