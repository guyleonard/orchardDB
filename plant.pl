#!/usr/bin/env perl
use strict;
use warnings;

use Bio::DB::Taxonomy;
use Bio::SeqIO::fasta;
use Bio::SeqIO;
use Bio::Tree::Tree;
use Cwd;
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
my $version = "OrchardDB v1.0 -- plant.pl v0.1";

# things
my $work_dir = cwd();
my $info     = 1;

# input directories etc
my $input_fasta_dir;     # original FASTA format protein directory
my $output_fasta_dir;    # modified FASTA format protein directory
my $ncbi_taxid_file;
my $ncbi_taxdump_dir;
my $ome_type = "DNA";    #DNA (genome) or RNA (transcriptome)

# database access
my $ip_address = q{};
my $user;
my $password;
my $table_name;
my $annotation_version = '1';

# options
my $setup;
my $populate;
my $mysql = 1;

if ( !@ARGV ) {
    help_message();
}

GetOptions(
    'setup'     => \$setup,
    'user|u=s'  => \$user,
    'pass|p=s'  => \$password,
    'ip|i=s'    => \$ip_address,
    'table|t=s' => \$table_name,
    'populate'  => \$populate,
    'in=s'      => \$input_fasta_dir,
    'out=s'     => \$output_fasta_dir,
    'ncbi=s'    => \$ncbi_taxid_file,
    'dump=s'    => \$ncbi_taxdump_dir,
    'mysql=i'   => \$mysql,

    'version|v' => sub { say "$version" },
    'help|h'    => sub { help_message() }
) or help_message();

########################
##        MAIN        ##
########################

if ($setup) {
    if ( $user && $password && $ip_address && $table_name ) {
        say
            "Setting up the table $table_name in MySQL $user\@$ip_address:OrchardDB";
        setup_mysql_db( $user, $password, $ip_address, $table_name );
    }
    else {
        say "You are Missing Variables";
        help_message();
    }
}

if ($populate) {
    if (   $user
        && $password
        && $ip_address
        && $table_name
        && $input_fasta_dir
        && $output_fasta_dir
        && $ncbi_taxid_file
        && $ncbi_taxdump_dir )
    {
        say "\nRunning: $version\n";

        # read in genome filenames
        my @fasta_input = get_genome_files($input_fasta_dir);

        # read in ncbi taxids associated with filenames
        my @ncbi_taxids = read_file( "$ncbi_taxid_file", chomp => 1 );

        foreach my $file_path (@fasta_input) {

            # find the absolute path for input files, if not specified
            my $abs_path = File::Spec->rel2abs($file_path);

            # extract the directory structure into source/subsource
            # and filename
            my @parts     = split /\//, $file_path;
            my $source    = $parts[1];
            my $subsource = $parts[1];
            my $filename  = $parts[2];
            if ( $source ne 'NCBI' ) {
                $subsource = $parts[2];
                $filename  = $parts[3];
            }
            
            # Skip over files not in sub folders
            if (! defined $filename) {
                say "\t[WARN] Erroneous file $file_path - skipping. Please put in correct folder.";
                next;
            }

            # Get the NCBI taxid from the input file if it exists in the
            # input file/taxid match list
            my ( $filenamex, $taxid );
            if (my ($match) = grep { $_ =~ $filename } @ncbi_taxids) {
                ( $filenamex, $taxid, $ome_type, $annotation_version ) = split /,/, $match;
                if (! defined $ome_type or $ome_type eq '') { $ome_type = 'DNA'}
                if (! defined $annotation_version or $annotation_version eq '') { $annotation_version = '1'}
            }
            else {
                say "\t[ERROR] The $filename file is missing from input file but exists in the input dir.";
                next;
            }
            
            # Check for existing taxa based on taxid
            my $taxa_exists
                = check_taxa_in_mysql( $user, $password, $ip_address,
                $table_name, $taxid );
            if ( $taxa_exists eq 1 ) {
                print
                    "\t[WARN] Skipping: $filename - $taxid as it exists in the orchardDB already.\n";
                next;
            }

            # check if a file in gzip, if so
            # we need to unzip it and update file_path
            if ( $filename =~ /\.gz$/ ) {
                $filename =~ s/\.gz$//;
                say "Unzipping: $filename from $abs_path";
                my $status = gunzip "$abs_path" => "$filename"
                    or die "gunzip failed: $GunzipError\n";
                $file_path =~ s/\.gz//;
            }

            # set up the output path which will be in the
            # directory one up from the absolute path given
            # by the input directory and named by the user input
            my @dir         = split $input_fasta_dir, $abs_path;
            my $input_path  = "$dir[0]";
            my $output_path = "$dir[0]$output_fasta_dir";

            ## Get and convert taxids to taxonomy
            #
            my ($full_name, $superkingdom, $kingdom, $subkingdom,
                $phylum,    $subphylum,    $class,   $order,
                $family,    $special
            ) = get_taxonomy( $filename, $taxid );

            ## Process fasta files
            # read in the original file and process it to have
            # new headers and output in the output folder
            say "Reading: $file_path";
            my $seqio_process = open_seqio($file_path);
            process_fasta( $seqio_process, $output_path, $filename,
                $full_name );

            ## Construct MySQL input
            # date time values in 'YYYY-MM-DD HH:MM:SS'
            my $date_time = DateTime->now( time_zone => 'local' )->datetime();

            # Remove the erroneous T - not good for MYSQL
            $date_time =~ s/T/ /igs;

            ##
            my $seqio_mysql = open_seqio($file_path);
            say "[INFO] $taxid // $source // $subsource // $ome_type // $annotation_version" if $info == 1;
            if ( $source =~ /JGI/i ) {

                my @mysql_push = process_jgi(
                    $seqio_mysql,  $filename,           $full_name,
                    $date_time,    $source,             $subsource,
                    $ome_type,     $annotation_version, $taxid,
                    $superkingdom, $kingdom,            $subkingdom,
                    $phylum,       $subphylum,          $class,
                    $order,        $family,             $special,
                );

                if ( $mysql == 1 ) {
                    print "Inserting: $full_name - ";
                    insert_mysql(
                        $user,       $password, $ip_address,
                        $table_name, @mysql_push
                    );
                }
                print "done!\n\n";

            }
            elsif ( $source =~ /NCBI/i ) {
                my @mysql_push = process_ncbi(
                    $seqio_mysql,  $filename,           $full_name,
                    $date_time,    $source,             $subsource,
                    $ome_type,     $annotation_version, $taxid,
                    $superkingdom, $kingdom,            $subkingdom,
                    $phylum,       $subphylum,          $class,
                    $order,        $family,             $special,
                );

                if ( $mysql == 1 ) {
                    print "Inserting: $full_name - ";
                    insert_mysql(
                        $user,       $password, $ip_address,
                        $table_name, @mysql_push
                    );
                }
                print "done!\n\n";

            }
            elsif ( $source =~ /Ensembl/i ) {
                my @mysql_push = process_ensembl(
                    $seqio_mysql,  $filename,           $full_name,
                    $date_time,    $source,             $subsource,
                    $ome_type,     $annotation_version, $taxid,
                    $superkingdom, $kingdom,            $subkingdom,
                    $phylum,       $subphylum,          $class,
                    $order,        $family,             $special,
                );

                if ( $mysql == 1 ) {
                    print "Inserting: $full_name - ";
                    insert_mysql(
                        $user,       $password, $ip_address,
                        $table_name, @mysql_push
                    );
                }
                print "done!\n\n";

            }
            elsif ( $source =~ /EuPathDB/i ) {
                my @mysql_push = process_eupathdb(
                    $seqio_mysql,  $filename,           $full_name,
                    $date_time,    $source,             $subsource,
                    $ome_type,     $annotation_version, $taxid,
                    $superkingdom, $kingdom,            $subkingdom,
                    $phylum,       $subphylum,          $class,
                    $order,        $family,             $special,
                );

                if ( $mysql == 1 ) {
                    print "Inserting: $full_name - ";
                    insert_mysql(
                        $user,       $password, $ip_address,
                        $table_name, @mysql_push
                    );
                }
                print "done!\n\n";
            }
            else {
                my @mysql_push = process_other(
                    $seqio_mysql,  $filename,           $full_name,
                    $date_time,    $source,             $subsource,
                    $ome_type,     $annotation_version, $taxid,
                    $superkingdom, $kingdom,            $subkingdom,
                    $phylum,       $subphylum,          $class,
                    $order,        $family,             $special,
                );

                if ( $mysql == 1 ) {
                    print "Inserting: $full_name - ";
                    insert_mysql(
                        $user,       $password, $ip_address,
                        $table_name, @mysql_push
                    );
                }
                print "done!\n\n";

            }

            # gzip
        }

    }
    else {
        say "You are Missing Variables";
        help_message();
    }
}

########################
##   Portal SUBS      ##
########################

# takes bioperl seqio object, along with
sub process_jgi {
    my ($seqio_object, $filename,           $full_name,
        $date_time,    $source,             $subsource,
        $ome_type,     $annotation_version, $taxid,
        $superkingdom, $kingdom,            $subkingdom,
        $phylum,       $subphylum,          $class,
        $order,        $family,             $special,
    ) = @_;
    my $accession;

    my @array_for_mysql;

    print "Preparing data: ";

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;

        # each JGI portals has different headers
        # some of the fungi may also break here
        if ( $subsource =~ /fungi|mycocosm/i ) {

            # jgi|Encro1|1|EROM_010010m.01
            $original_header =~ /jgi[|].*[|](\d+)[|].*/;
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

        # remove all commas from headers prior to submission
        # to mysql insertion - causes issues!
        $original_header =~ s/\,//g;

        # this must not have spaces!
        my $record
            = "$hashed_accession,$accession,$original_header,$filename,$full_name,$date_time,$source,$subsource,$ome_type,$annotation_version,$taxid,$superkingdom,$kingdom,$subkingdom,$phylum,$subphylum,$class,$order,$family,$special";

        push @array_for_mysql, $record;
    }
    print "done!\n";

    return @array_for_mysql;
}

sub process_ensembl {
    my ($seqio_object, $filename,           $full_name,
        $date_time,    $source,             $subsource,
        $ome_type,     $annotation_version, $taxid,
        $superkingdom, $kingdom,            $subkingdom,
        $phylum,       $subphylum,          $class,
        $order,        $family,             $special,
    ) = @_;
    my $accession;

    my @array_for_mysql;

    print "Preparing data: ";

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;

        #EER13651 pep supercontig:JCVI_PMG_1.0:scf_1104 ...
        $original_header =~ /(.*)\s+pep\s+.*/;
        $accession = $1;

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);

        # remove all commas from headers prior to submission
        # to mysql insertion - causes issues!
        $original_header =~ s/\,//g;

        # this must not have spaces!
        my $record
            = "$hashed_accession,$accession,$original_header,$filename,$full_name,$date_time,$source,$subsource,$ome_type,$annotation_version,$taxid,$superkingdom,$kingdom,$subkingdom,$phylum,$subphylum,$class,$order,$family,$special";

        push @array_for_mysql, $record;

    }
    print "done!\n";

    return @array_for_mysql;
}

sub process_ncbi {
    my ($seqio_object, $filename,           $full_name,
        $date_time,    $source,             $subsource,
        $ome_type,     $annotation_version, $taxid,
        $superkingdom, $kingdom,            $subkingdom,
        $phylum,       $subphylum,          $class,
        $order,        $family,             $special,
    ) = @_;
    my $accession;
    my $warning = 0;

    my @array_for_mysql;

    print "Preparing data: ";

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;

        if ( $seq->id =~ /^gi/ ) {
            say
                "\n\t[WARN] Old NCBI Headers Detected. Considering updating your data."
                if $warning == 1;
            $original_header =~ /gi\|.*\|.*\|(.*)\|.*/;
            $accession = $1;
            $warning++;
        }
        else {
            $accession = $seq->id;
        }

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);

        # remove all commas from headers prior to submission
        # to mysql insertion - causes issues!
        $original_header =~ s/\,//g;

        # this must not have spaces!
        my $record
            = "$hashed_accession,$accession,$original_header,$filename,$full_name,$date_time,$source,$subsource,$ome_type,$annotation_version,$taxid,$superkingdom,$kingdom,$subkingdom,$phylum,$subphylum,$class,$order,$family,$special";

        push @array_for_mysql, $record;

    }
    print "done!\n";

    return @array_for_mysql;
}

sub process_eupathdb {
    my ($seqio_object, $filename,           $full_name,
        $date_time,    $source,             $subsource,
        $ome_type,     $annotation_version, $taxid,
        $superkingdom, $kingdom,            $subkingdom,
        $phylum,       $subphylum,          $class,
        $order,        $family,             $special,
    ) = @_;
    my $accession;

    my @array_for_mysql;

    print "Preparing data: ";

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;

     #AEWD_010030-t26_1-p1 | transcript=AEWD_010030-t26_1 | gene=AEWD_010030 |
        $original_header =~ /.*gene=(.*)\s+\|\s+org.*/;
        $accession = $1;

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);

        # remove all commas from headers prior to submission
        # to mysql insertion - causes issues!
        $original_header =~ s/\,//g;

        # this must not have spaces!
        my $record
            = "$hashed_accession,$accession,$original_header,$filename,$full_name,$date_time,$source,$subsource,$ome_type,$annotation_version,$taxid,$superkingdom,$kingdom,$subkingdom,$phylum,$subphylum,$class,$order,$family,$special";

        push @array_for_mysql, $record;

    }
    print "done!\n";

    return @array_for_mysql;
}

sub process_other {
    my ($seqio_object, $filename,           $full_name,
        $date_time,    $source,             $subsource,
        $ome_type,     $annotation_version, $taxid,
        $superkingdom, $kingdom,            $subkingdom,
        $phylum,       $subphylum,          $class,
        $order,        $family,             $special,
    ) = @_;
    my $accession;

    my @array_for_mysql;

    print "Preparing data: ";

    while ( my $seq = $seqio_object->next_seq() ) {

        # get full header, made from id and description
        my $original_header = $seq->id . ' ' . $seq->desc;

        $accession = $seq->id;

        # replace header info with a hash
        my $hashed_accession = hash_header($original_header);

        # remove all commas from headers prior to submission
        # to mysql insertion - causes issues!
        $original_header =~ s/\,//g;

        # this must not have spaces!
        my $record
            = "$hashed_accession,$accession,$original_header,$filename,$full_name,$date_time,$source,$subsource,$ome_type,$annotation_version,$taxid,$superkingdom,$kingdom,$subkingdom,$phylum,$subphylum,$class,$order,$family,$special";

        push @array_for_mysql, $record;

    }
    print "done!\n";

    return @array_for_mysql;
}

########################
##        SUBS        ##
########################

sub check_taxa_in_mysql {
    my ( $user, $password, $ip_address, $table_name, $taxid ) = @_;

    my $dsn  = "dbi:mysql:database=orchardDB;host=$ip_address";
    my %attr = ( PrintError => 0, RaiseError => 1, AutoCommit => 1 );
    my $dbh  = DBI->connect( $dsn, $user, $password, \%attr )
        or die "Couldn't connect to database: " . DBI->errstr;

    # DEFINE A MySQL QUERY
    my $statement
        = $dbh->prepare(
        "SELECT * FROM orchardDB.$table_name WHERE taxid='$taxid' LIMIT 1;")
        or die "Couldn't connect to database: " . DBI->errstr;

    my $status = $statement->execute();

    return $status;
}

sub insert_mysql {

    my ( $user, $password, $ip_address, $table_name, @mysql_rows ) = @_;

    my $dsn  = "dbi:mysql:database=orchardDB;host=$ip_address";
    my %attr = ( PrintError => 0, RaiseError => 1, AutoCommit => 1 );
    my $dbh  = DBI->connect( $dsn, $user, $password, \%attr )
        or die "Couldn't connect to database: " . DBI->errstr;

    # DEFINE A MySQL QUERY
    my $statement = $dbh->prepare(
        "INSERT IGNORE into $table_name
       (
         hashed_accession, extracted_accession, original_header,
         original_fn, new_fn, date_added,
         source, subsource, type, version, taxid,
         t_superkingdom, t_kingdom, t_subkingdom, 
         t_phylum, t_subphylum, t_class, 
         t_order, t_family, t_special
       )
       VALUES
       (
         ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?
       );"
    ) or die "Couldn't connect to database: " . DBI->errstr;

    foreach my $row (@mysql_rows) {
        $statement->execute( split /,/, $row );
    }

    # close the database connection
    $dbh->disconnect;
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

        # replace with X if not a valid protein code, not useful in blast
        # or alignment downstream
        $sequence =~ s/[^A-z|^\-]/X/g;
        $seq->seq("$sequence");

        $output->write_seq($seq);
    }
}

sub get_taxonomy {
    my ( $filename, $taxid ) = @_;

    # if the sqlite db does not exist, warn user
    if ( !-f "$ncbi_taxdump_dir\/taxonomy.sqlite" ) {
        say
            "[INFO]:\tIndexing NCBI Taxonomy - This may take a few minutes on the first run!";
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
        return if !/\.fa|\.faa|\.fas|\.fasta|\.aa|\.pep|\.gz/;
        push @fasta_files, $File::Find::name;
    };
    find( $file_finder, $input_dir );

    # sort the order
    @fasta_files = sort @fasta_files;

    return @fasta_files;
}

# MySQL Database called OrhcardDB, tables are user named
# All DBs include these columns:
# hashed_accession = hash of the header from original file
# original_fn, new_fn = filenames for tracking
# original header
# extracted "accession", e.g. NCBI accessions
# date of inclusion
# source/subsource DB, e.g. NCBI, JGI, Ensenmbl, Other, etc
# taxonomy information
sub setup_mysql_db {

    my ( $user, $password, $ip_address, $table_name ) = @_;

    # connect directly to the MySQL server, without a DB
    my $dsn  = "DBI:mysql:host=$ip_address";
    my %attr = ( PrintError => 0, RaiseError => 1 );
    my $dbh  = DBI->connect( $dsn, $user, $password, \%attr )
        or die "Couldn't connect to database: " . DBI->errstr;

    # if the orchardDB database doesn't exist then create it
    my $create_database = ("CREATE DATABASE IF NOT EXISTS orchardDB;");
    $dbh->do($create_database);

    # reconnect to the server using the orchardDB
    $dsn = "dbi:mysql:database=orchardDB;host=$ip_address";
    $dbh = DBI->connect( $dsn, $user, $password, \%attr )
        or die "Couldn't connect to database: " . DBI->errstr;

    # create the table schema
    # STORAGE:
    # TEXT = 2 + c, where c is length of string
    # VARCHAR = 1 + c up to 255 chars
    my $create_table = (
        "CREATE TABLE $table_name
  (
     hashed_accession    VARCHAR(32) NOT NULL DEFAULT '',
     extracted_accession VARCHAR(25) DEFAULT NULL,
     original_header     TEXT DEFAULT NULL,
     original_fn         TEXT DEFAULT NULL,
     new_fn              TEXT DEFAULT NULL,
     date_added          DATETIME DEFAULT NULL,
     source              TEXT DEFAULT NULL,
     subsource           TEXT DEFAULT NULL,
     type                VARCHAR(3) DEFAULT NULL,
     version             TEXT DEFAULT NULL,
     taxid               TEXT DEFAULT NULL,
     t_superkingdom      VARCHAR(50) DEFAULT NULL,
     t_kingdom           VARCHAR(50) DEFAULT NULL,
     t_subkingdom        VARCHAR(50) DEFAULT NULL,
     t_phylum            VARCHAR(50) DEFAULT NULL,
     t_subphylum         VARCHAR(50) DEFAULT NULL,
     t_class             VARCHAR(50) DEFAULT NULL,
     t_order             VARCHAR(50) DEFAULT NULL,
     t_family            VARCHAR(50) DEFAULT NULL,
     t_special           VARCHAR(50) DEFAULT NULL,
     PRIMARY KEY (hashed_accession)
  ) engine=innodb;"
    );

    $dbh->do($create_table);

    say "The $table_name in OrchardDB was created successfully!";

    # disconnect from the MySQL database
    $dbh->disconnect();
}

# The idea is that every header will be different, even across
# different taxa, but they are messy and we need a unique ID,
# hashes are perfect for this. They're not human readable, but
# we'll be converting them back to Genus species names along
# with the extracted accession anyway.
sub hash_header {
    my $header = shift;
    $header = md5_hex($header);
    return $header;
}

sub help_message {
    say "$version";
    say "Usage: perl plant.pl [options]\nRequired:";
    say
        "\t-user <username> -pass <password> -ip <ip address> -table <tablename>";
    say "Setup Database:";
    say "\t--setup [required options]";
    say "Populate Database:";
    say
        "\t--populate [required options] -in <input directory> -out <output directory> -ncbi <NCBI taxa ID list> -dump <NCBI taxdump directory>";
    say "Options:";
    say "-type = DNA or RNA (default: DNA)";

    exit(1);
}
