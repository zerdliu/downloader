BEGIN {
    unshift @INC, '../lib';
}
use strict ; 
use Test::More qw( no_plan ); 
use downloader ; 


#TODO: {
#   local $TODO = 'to do list' ; 
#   ok( ParseDesFile ) ; 
#   ok( UpdateFileOrDir ) ; 
#   ok( GetValueFromUpdateList ) ; 
#   ok( RemoveUselessFiles ) ; 
#   ok( GetAllLocalFiles ) ; 
#   ok( GetUpdateFileList ) ; 
#}
ok( ParseDynamicFile("localhost:/bin/sh") eq "localhost:bash") ; 

#TODO: {
#   local $TODO = 'to do list' ;
#   ok( GetFileWithRetry ) ;  
#   ok( GetFile ) ; 
#}

ok( TransScpUrlToFtpUrl("localhost:/bin/bash") eq "ftp://localhost/bin/bash", "TransScpUrlToFtpUrl ok .") ; 

ok( GetFtpUrlFileType("ftp://localhost/bin/bash") eq "f" ) ;
ok( GetFtpUrlFileType("ftp://localhost/bin") eq "d" ) ;  
ok( GetFtpUrlFileType("ftp://localhost/bin/sh") eq "f" ) ; 
#TODO: {
#   local $TODO = 'to do list' ; 
#   ok( CheckMd5 ) ; 
#}



ok( GetRemoteFileSize("ai-imci-control00.ai01:/bin/bash") eq 752272 , "localhost:/bin/bash is 752272 Byte.") ; 

my $test_file_1 = do { local $/ ; <DATA> } ;

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

__DATA__
this is a test file.

