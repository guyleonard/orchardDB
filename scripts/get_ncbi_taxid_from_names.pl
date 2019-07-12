#!/usr/bin/env perl
use warnings;
use Cwd;               # Gets pathname of current working directory
use DBI;               # mysql database access
use File::Basename;    # Remove path information and extract 8.3 filename
use Bio::Taxon;
use Bio::TreeIO;
use Bio::DB::Taxonomy;
use Bio::Tree::Tree;

# Directory Settings
my $WORK_DIR = getcwd;
my $input    = shift;

open( my $file_in, '<', $input );

my $first_line = <$file_in>;

foreach my $line (<$file_in>) {

    my @current_line = split( /,/, $line );

    #my $taxon_name = $line;

    my $taxon_name
        = "$current_line[0] $current_line[1] $current_line[2]";# $current_line[3]";

    #my $original_taxid = "$current_line[9]";
    #print "Read in: $taxon_name\n";

    #my $split_taxon_name = &split_taxon_name("$taxon_name");
    my $taxid = &get_ncbi_taxid("$taxon_name");

    my $db = Bio::DB::Taxonomy->new(-source => 'entrez');
    my $taxon = $db->get_taxon(-taxonid => $taxid);
    $taxon = $taxon->node_name;

    #print "ID: $taxid\n";

    #my $colour = &get_ncbi_taxonomy("$taxon_name");

    #print "Identified: $taxon_name\tNCBI: $leaf_name_id\n";
    #print $file_out "$leaf_name,$split_taxon_name$leaf_name_id,0,$colour\n";
    #print "$split_taxon_name$taxon_name,$taxid,$original_taxid\n";
    print "$taxon_name,$taxon,$taxid\n";    #,$colour\n";

}

sub get_ncbi_taxid {

    my $query = shift;

    my ( $genus, $species, $extra, $strain ) = split( / /, $query );
    $query =~ s/[,]/ /g;

    my $taxa;
    my $taxa_id;

    my $dbh = Bio::DB::Taxonomy->new( -source => 'entrez' );

    # I cannot get NCBI to search/return for names that include
    # strain IDs or sp/sp. in their names.
    #if ( $species eq "sp." || $species eq "sp" ) {
    #    $taxa = $dbh->get_taxon( -name => "$genus" );
    #}
    #else {
    #    $taxa = $dbh->get_taxon( -name => "$genus $species" );
    #}
    #my $taxa_id = $taxa->id;
    if ( $query
        =~ m/Amphiambly|Bisporella|Cadophora|Chytriomyces|Clavulina|Coniella|Coniochaeta|Dentipellis|Emmonsia|Fibulorhizoctonia|Hypoxylon|Lachancea|Lecythophora|Leptodontium|Leucoagaricus|Mariannaea|Melanconium|Moniliella|Nematocida|Ophiostoma|Peniophora|Phyllosticta|Piromyces|Pseudogymnoascus|Purpureocillium|Pyrenochaeta|Rhodotorula|Saccharomyces|Scytinostroma|Septobasidium|Stagonospora|Termitomyces|Thozetella|Tilletiopsis|Tritirachium|Umbelopsis|Vavraia|Xylariales/g
        )
    {
        $query = $query;
    }
    elsif ( $query =~ m/f. sp./g ) {
        $query = $query;
    }
    else {
        $query =~ s/sp\.//;
    }

    #print "Trying: $query\n";
    $taxa = $dbh->get_taxon( -name => "$query" );
    if ( defined $taxa ) {
        $taxa_id = $taxa->id;
    }
    else {
        #print "Can't get taxa with strain. Trying as: $genus $species\n";
        $taxa = $dbh->get_taxon( -name => "$genus $species" );
        if ( defined $taxa ) {
            $taxa_id = $taxa->id;
        }
        else {
            #print "Not in NCBI";
            $taxa = $dbh->get_taxon( -name => "$genus" );
            $taxa_id = $taxa->id;
        }
    }

    return "$taxa_id";
}

sub get_ncbi_taxonomy {

    my $query = shift;
    my ( $genus, $species ) = split( / /, $query );
    my $unknown;
    my $colour;
    print "$genus $species\n";

    my $dbh = Bio::DB::Taxonomy->new( -source => 'entrez' );

    # Retreive taxon_name
    if ( $species eq "sp." || $species eq "sp" ) {
        $unknown = $dbh->get_taxon( -name => "$genus" );
    }
    else {
        $unknown = $dbh->get_taxon( -name => "$genus $species" );
    }

    my $tree_functions = Bio::Tree::Tree->new();

    # and get the lineage of the taxon_name
    my @lineage = $tree_functions->get_lineage_nodes($unknown);

    # Then we can extract the name of each node
    #which will give us the Taxonomy lineages...
    my $taxonomy = "";
    foreach my $item (@lineage) {
        my $name = $item->node_name;
        my $rank = $item->rank;
        $taxonomy = "$taxonomy$name\[$rank\],";
    }

    return $taxonomy;

    #print "Taxonomy = $taxonomy\n\n";

    #my $group = "";
    #for my $key ( keys %taxa_colours ) {
    #    my $value = $taxa_colours{$key};
    #    if ( $taxonomy =~ m/$key/igsm ) {
    #        #print "$key - $value - Yep\n";
    #        $group  = $key;
    #        $colour = $value;
    #    }
    #}

    #print "C: $colour\tT: $group\n";
    #return "$colour,$group";
}

sub split_taxon_name {

    my $taxon_name       = shift;
    my $split_taxon_name = "";

    #print "T: $taxon_name\n";

    # I can't just split on space like this:
    # my ( $genus, $species, $strain) = split( / /, $taxon_name );
    # because some taxa don't conform:
    # e.g. Thelebolus microsporus ATCC 90970
    # e.g. Aureobasidium pullulans var. pullulans EXF-150
    # GREAT

    my @strings = ( $taxon_name =~ /(\w+)/g );
    my ( $genus, $species, $strain ) = "";

    if ( $#strings == '0' ) {
        $genus            = $strings[0];
        $split_taxon_name = "$genus,,,";
    }
    elsif ( $#strings == '1' ) {
        $genus            = $strings[0];
        $species          = $strings[1];
        $split_taxon_name = "$genus,$species,,";

        #print "G:$genus\t$species\n";
    }
    elsif ( $#strings == '2' ) {
        $genus            = $strings[0];
        $species          = $strings[1];
        $strain           = $strings[2];
        $split_taxon_name = "$genus,$species,$strain,";
    }

    # genus + species + strain = 3
    # If the array is bigger than 4 - 1
    elsif ( $#strings >= '3' ) {
        if ( $strings[2] eq "var" || $strings[2] eq "var." ) {
            $genus            = $strings[0];
            $species          = $strings[1];
            $strain           = "$strings[4]_$strings[5]";
            $split_taxon_name = "$genus,$species,$strain,";
        }
        else {
            $genus            = $strings[0];
            $species          = $strings[1];
            $strain           = "$strings[2]_$strings[3]";
            $split_taxon_name = "$genus,$species,$strain,";
        }
    }

    #print "R: $split_taxon_name\n";
    return $split_taxon_name;
}
