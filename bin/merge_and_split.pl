#!/usr/bin/perl
BEGIN{
   use Cwd 'realpath';
   $g_script=__FILE__;
   $g_base_path=realpath($g_script);
   $g_base_path=~ s/[^\/]+$//;
   $g_lib_path=$g_base_path."../lib";
   unshift(@INC,$g_lib_path);
}     
use strict ; 
use warnings ; 
use YAML::Syck ;
use Data::Dumper ; 
use File::Basename ; 
use File::stat ;
use File::Compare ;
use File::Copy;
use IO::File ; 
use threads ;
use Thread::Queue ;
use threads::shared qw(cond_wait cond_broadcast) ;
use Getopt::Long ;
use downloader ; 

our $yaml_file = "" ; 
our $version = "1.0.0" ; 
our $self_name = __FILE__ ; 
our $show_version = sub { print $self_name." : ".$version."\n" ; exit  } ; 
our $through = "" ; 
our $EXIT_STATUS = 0 ; 
our $threshold = 50 ; 

my $usage = <<END 
usage: $self_name [options]

  perl $self_name -f ./data/data.yaml --through=server:path/name --threshold=50

  options are:
    -? -h --help          show this message
    -v --version          show version
    -f --yaml-file        input yaml file
    --through             middle layer, scp path
    --threshold           data.yaml split threshold
END
;
my $cmd_config = GetOptions(
    "yaml-file|f=s" => \$yaml_file, 
    "help|?|h!" => sub{ print $usage ; exit  }, 
    "version|v!" => $show_version , 
    "through=s" => \$through , 
    "threshold=s" => \$threshold, 
) ;

$threshold = $threshold * 1024 * 1024 ; 
unless ( $yaml_file ) {
    print "Fatal: --yaml-file must be set.\n" ; 
    print $usage ; 
    exit 111 ; 
}

unless ( -f $yaml_file ) {
    print "Fatal: $yaml_file is not exist.\n" ; 
    exit 113 ; 
}

unless (ParseDynamicFile($through)) {
    print "FATAL: $through address wrong \n" ; 
    exit 11
}

my $yaml ; 
$yaml = LoadFile("$yaml_file") ;

my %check_source ;
my %check_middle ; 

for my $label (keys %{$yaml}) {
    my $a_data_ref = $$yaml{"$label"} ;

    ## just handle dynamic data
    if ( $a_data_ref -> {"type"} eq "dynamic" ) {

        ## generate middle_address , if in data.yaml have strategy , use strategy for path. 
        my $middle_address ; 
        if ( $a_data_ref -> { "strategy" } ) { 
            $middle_address = $through . "/" . basename($a_data_ref -> { "source" }) . "/" . $a_data_ref -> { "strategy"} . "/" . basename($a_data_ref -> { "source" }) ; 
        } else {
            $middle_address = $through . "/" . basename($a_data_ref -> { "source" }) . "/" . basename($a_data_ref -> { "source" }) ;
        }

        my $file_size = GetRemoteFileSize( $a_data_ref -> { "source" } ) ; 
        $a_data_ref -> { "middle_address" } = $middle_address ; 
        $a_data_ref -> { "file_size" } = $file_size ; 
        
        ## source could not repeate. if repeat, exclude it. 
        if ( exists $check_source{$a_data_ref -> { "source" }} ) {
            delete $$yaml{$label} ;  
        } else {
            $check_source{$a_data_ref -> { "source" } } = 0 ; 
        }
        ## middle_address could not repeat. if repeat, exit and show error.
        if ( exists $check_middle{$a_data_ref -> { "middle_address" }} ) {
            print "FATAL: middle_address repeat. " . $a_data_ref -> { "middle_address" } . "\n" ;  
            exit 11 ; 
        } else {
            $check_middle{$a_data_ref -> { "middle_address" } } = 0 ; 
        }

    } else {
        delete $$yaml{$label} ; 
    }
}

our $output_yaml_file_big = "upstream_big.yaml" ; 
our $output_yaml_file_small = "upstream_small.yaml" ; 
our $output_yaml_big  ; 
our $output_yaml_small  ; 

for my $label (keys %{$yaml}) {
    my $a_data_ref = $$yaml{"$label"} ;
    
    if ( $a_data_ref -> { "file_size" } >= $threshold ) {
        $output_yaml_big -> { $label } = $a_data_ref ; 
    } else {
        $output_yaml_small -> { $label } = $a_data_ref ; 
    }
print Dumper $output_yaml_small ; 
    delete $$yaml{$label}{"file_size"} ; 
    delete $$yaml{$label}{"middle_address"} ; 
}

DumpFile($output_yaml_file_small, $output_yaml_small) ; 
DumpFile($output_yaml_file_big, $output_yaml_big) ; 
