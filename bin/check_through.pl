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

my $usage = <<END 
usage: $self_name [options]

  perl $self_name -f ./data/data.yaml --through=server:path/name

  options are:
    -? -h --help          show this message
    -v --version          show version
    -f --yaml-file        input yaml file
    --through             middle layer, scp path
END
;
my $cmd_config = GetOptions(
    "yaml-file|f=s" => \$yaml_file, 
    "help|?|h!" => sub{ print $usage ; exit  }, 
    "version|v!" => $show_version , 
    "through=s" => \$through , 
) ;

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

for my $label (keys %{$yaml}) {
    my $a_data_ref = $$yaml{"$label"} ;
    if ( $a_data_ref -> {"type"} eq "dynamic" ) {
        my $middle_address = $through . "/" . basename($a_data_ref -> { "source" }) . "/" . basename($a_data_ref -> { "source" }) ; 
        if (ParseDynamicFile($middle_address)) {
            print "Notice: $label exist. middle address: $middle_address. source address:" . $a_data_ref -> { "source" } . "\n"; 
        } elsif ( ParseDynamicFile($a_data_ref -> { "source" }) ) {
            ## exit 10 , must trig upstream yaml file update.
            $EXIT_STATUS = 10 ; 
        } else {
            print "FATAL: label:$label source:" . $a_data_ref -> { "source" } . "not exist ,please check.\n" ; 
            exit 11 
        }
    }
}

exit $EXIT_STATUS ; 
