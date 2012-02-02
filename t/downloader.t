BEGIN {
    unshift @INC, '../lib';
}
use strict ; 
use Test::More qw( no_plan ); 
use Data::Dumper ; 
use downloader ; 

mkdir "./test" ; 
chdir "./test" ; 
#TODO: {
#   local $TODO = 'to do list' ; 
#   ok( ParseDesFile ) ; 
#   ok( UpdateFileOrDir ) ; 
#   ok( GetValueFromUpdateList ) ; 
#   ok( RemoveUselessFiles ) ; 
#   ok( GetAllLocalFiles ) ; 
#   ok( GetUpdateFileList ) ; 
#}
ok( ParseDynamicFile("localhost:/bin/no_such_file") eq undef) ; 
ok( ParseDynamicFile("localhost:/bin/sh") eq "localhost:bash") ; 

#TODO: {
#   local $TODO = 'to do list' ;
#   ok( GetFileWithRetry ) ;  
#   ok( GetFile ) ; 
#}

ok( TransScpUrlToFtpUrl("localhost:/bin/bash") eq "ftp://localhost/bin/bash", "TransScpUrlToFtpUrl ok .") ; 

#ok( GetFtpUrlFileType("ftp://no_such_host/bin/bash") eq undef ) ;
ok( GetFtpUrlFileType("ftp://localhost/no_such_file") eq undef ) ;
ok( GetFtpUrlFileType("ftp://localhost/bin/bash") eq "f" ) ;
ok( GetFtpUrlFileType("ftp://localhost/bin") eq "d" ) ;  
ok( GetFtpUrlFileType("ftp://localhost/bin/sh") eq "f" ) ; 
#TODO: {
#   local $TODO = 'to do list' ; 
#   ok( CheckMd5 ) ; 
#}



ok( GetRemoteFileSize("localhost:/bin/bash") eq 752272 , "localhost:/bin/bash is 752272 Byte.") ; 


my $file = "test-file1.txt";
die if -f $file;
open(F, ">$file") || die "Can't create '$file': $!";
binmode(F);
print F "this is a test file" ;
close(F) || die "Can't write '$file': $!";


$file = "test-file1.txt.md5";
die if -f $file;
open(F, ">$file") || die "Can't create '$file': $!";
binmode(F);
print F "a5890ace30a3e84d9118196c161aeec2  test-file1.txt" ;
close(F) || die "Can't write '$file': $!";

ok( CheckMd5("./test-file1.txt", "./test-file1.txt.md5") ) ; 

$file = "test-file2.txt";
die if -f $file;
open(F, ">$file") || die "Can't create '$file': $!";
binmode(F);
print F "this is another test file" ;
close(F) || die "Can't write '$file': $!";

my $data = do { local $/ ; <DATA> } ;
$file = "data.yaml" ; 
die if -f $file;
open(F, ">$file") || die "Can't create '$file': $!";
binmode(F);
print F "$data" ; 
close(F) || die "Can't write '$file': $!";


ok( GetFile("yf-imci-data00.yf01:/home/work/var/CI_DATA/im/static/allocation_value.txt.4","./data/adr/allocation_value.txt","10","ftp") eq 1 ) ; 
ok( GetFile("yf-imci-data00.yf01:/home/work/var/CI_DATA/im/static/allocation_value.tx.4","./data/adr/allocation_value.txt","10","ftp") ne 1 ) ; 
#ok( GetFile("yf-imci-data00.yf01:/home/work/var/CI_DATA/im/static/allocation_value.txt.4","./data/adr/allocation_value.txt","10","gingko","-s 2") eq 1 ) ; 

ok( GetFileWithRetry("yf-imci-data00.yf01:/home/work/var/CI_DATA/im/static/allocation_value.txt.4","./data/adr/allocation_value.txt","","ftp") eq 1 ) ; 

chdir "../" ; 
system("rm -rf test") ; 



__DATA__
--- 
allocation_value.txt: 
  type: static
    source: yf-imci-data00.yf01:/home/work/var/CI_DATA/im/static/allocation_value.txt.4
      deploy_path: ./data/adr/allocation_value.txt
