#!/usr/bin/perl
#
# 删除在data目录下没有用的文件（不在data.yaml里面的）
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
use Data::Dumper ; 
use YAML::Syck ; 

my @local_files ;
foreach my $a_local_file (`find ./data -type f | grep -v '\.md5\$'`) {
    chomp $a_local_file ; 
    push @local_files, $a_local_file ; 
}
#print Dumper \@local_files ; 

my $yaml_file = "data.yaml" ; 
my $yaml = LoadFile($yaml_file) ; 
#print Dumper $yaml ; 

my @future_files ; 
foreach my $a_data (values %{$yaml}) {
    push @future_files, $a_data->{'deploy_path'} ; 
}

#print Dumper \@future_files ; 

foreach my $a_local_file (@local_files) {
    unless ( IsElementInArray($a_local_file, \@future_files) ) {
        print "delete $a_local_file\n" ;  
	system("rm -rf $a_local_file") ;
    } 
}

sub IsElementInArray {
    my ($element, $array_ref) = @_ ;
    for ( @{$array_ref} ) {
        if ( "$element" eq "$_" ) {
            return scalar 1 ;
        }
    }
    return scalar 0 ;
}
