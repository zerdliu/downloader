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

our $daemon = 0 ; 
our $interval = 3 ; 
our $yaml_file = "" ; 
our $parallel_num = 3 ; 
our $testing = 0 ; 
our $method ; 
our $version = "1.0.0" ; 
our $self_name = __FILE__ ; 
our $show_version = sub { print $self_name." : ".$version."\n" ; exit  } ; 
our $threshold ; 
our $data_type = "" ; 
our $download_rate = 10 ; 
our $wget_args= "" ; 
our $gingko_args= "" ; 
our $is_check_md5=0 ; 
our $through = "" ; 
our $stream = "" ; 
our $version_control = 0 ; 


my $usage = <<END 
usage: $self_name [options]

  perl ./deploy_script/downloader/bin/downloader.pl -f ./data/data.yaml [--threshold=2]

  options are:
    -? -h --help          show this message
    -v --version          show version
    --daemon              run as daemon
    -i --interval         sleep time between each instance when run as daemon
    -f --yaml-file        input yaml file
    -t --test             run as test , check yaml file format
    -p --parallel         parallel number when download files 
    -m --method           get file method: ftp|gingko
    --data-type           static|dynamic
    --threshold           threshold for ftp or gingko . below threshold use ftp , above threshold use gingko, default:0 , unit: M
    -l --download-rate    limit rate when download. default:10 , unit:M
    --check-md5           check md5
    --wget-args            
    --gingko-args          
    --through             middle address ,ssh-like address: server:/path/name, when use --stream , should be use --through at the same time.
    --stream              up|down . when use through , "up" to download from source to through addr, "down" to download from through addr to deploy path
    --version-control     use this args to control file version. offen use in --stream=up
END
;
my $cmd_config = GetOptions(
    "parallel|p=i" => \$parallel_num ,
    "daemon!" => sub { $daemon = 1 } ,
    "interval|i=i" => \$interval, 
    "method|m=s" => \$method, 
    "yaml-file|f=s" => \$yaml_file, 
    "test|t!" => sub { $testing = 1 }, 
    "help|?|h!" => sub{ print $usage ; exit  }, 
    "version|v!" => $show_version , 
    "data-type=s" => \$data_type , 
    "l|download-rate=i" => \$download_rate ,
    "threshold=i" => \$threshold ,
    "wget-args=s" => \$wget_args, 
    "gingko-args=s" => \$gingko_args, 
    "check-md5!" => \$is_check_md5 ,
    "through=s" => \$through,
    "stream=s" => \$stream,
    "version-control!" => sub { $version_control = "yes" },
) ;

if ( $threshold ) {
  $threshold = $threshold * 1024 * 1024 ; 
  if ($method) {
      print "Fatal: args error. Can't set -m and --threshold can't set at the same time.\n" ;  
      exit 134 ; 
  }
} else {
  $method = "gingko" unless $method ; 
}

unless ( $yaml_file ) {
    print "Fatal: --yaml-file must be set.\n" ; 
    print $usage ; 
    exit 11 ; 
}

unless ( -f $yaml_file ) {
    print "Fatal: $yaml_file is not exist.\n" ; 
    exit 12 ; 
}

## ָ����--stream ,�������--through 
if ( $stream ) {
    unless ( $through ) {
        print "FATAL: --through must be set.\n" ; 
        exit 11 ; 
    }
    if ( $stream ne "up" and $stream ne "down" ) {
        print "$stream \n" ; 
        print "FATAL: --stream must be 'up' or 'down', but you set $stream \n" ; 
        exit 11 ; 
    }
    unless ( ParseDynamicFile($through) ) {
        print "FATAL: $through address wrong \n" ; 
        exit 12
    }
}

our $queue ; 
our $DONE :shared = 0 ; 
$SIG{USR1} = sub { $DONE = 1 ; } ;
$SIG{TERM} = sub { $DONE = 1 ; } ;
my $DIST_THREAD_STATUS :shared = '' ; 
my %DIST_THREAD_STATUS :shared = () ; 
my $yaml ; 

if ( $daemon ) {
    my $pid_file = "./downloader.pid" ; 
    unless ( CreatPidFile($pid_file) ) {
        print "Fatal: create pid file fail. $pid_file \n" ; 
        WriteLog("Fatal: create pid file fail. $pid_file\n") ; 
        exit 100 ; 
    }
}

do {
    
    exit 320 unless TestLabel("$yaml_file") ; 
    exit 321 unless TestFormat("$yaml_file") ; 
    exit 322 unless TestKey("$yaml_file") ; 
    exit 323 unless TestDeployPath("$yaml_file") ; 
    exit 0 if ( $testing ) ; 
    ## ���������ļ����洢��ͨ�����ݽṹ
    $yaml = LoadFile("$yaml_file") ; 
    
    $queue = Thread::Queue->new() ;
    ## ��ʶ�߳��Ƿ��˳�
    $DONE = 0 ;
    
    my $update_list = GetUpdateFileList($yaml, $data_type) ; 
    ## ������
    my @sorted_update_list = sort { $a->{"file_size"} <=> $b->{"file_size"} } @{$update_list} ; 
    foreach my $aData ( @sorted_update_list ) {
        ## ��������ڴ�������ݣ��Թ�ȥ
        if ( grep {$DIST_THREAD_STATUS{$_} eq $$aData{"deploy_path"} } keys %DIST_THREAD_STATUS ) {
            print "Warning: " . $$aData{"deploy_path"} . "is delivering, wait for next time.\n" ; 
            WriteLog("Warning: " . $$aData{"deploy_path"} . "is delivering, wait for next time.\n") ; 
            next ;
        }
        $queue->enqueue($$aData{"deploy_path"}) unless $testing ;
    } 
    
    ## �����߳�,���Ѿ����߳��ڷַ�ʱ���ٴ����µ��߳�
    my $threads_num = 0;  
    for my $thr (threads->list()) {
        $threads_num++ ; 
    }
    if ( $threads_num < 3 ) {
        for ( 1..$parallel_num ) {
            threads->new(\&UpdateFile, \@sorted_update_list) ;
        }
    }
    
} while ( $daemon and not $DONE and (sleep $interval) ) ; 

## �ȴ�ֱ�������е��������,�����daemonģʽ����һֱ�ȴ�
while ( $queue->pending ) {;}
$daemon or $DONE = 1 ;
    
## �����߳�
for my $thr (threads->list()) {
    $thr->join();
}

#######----------------------------------function-----------------------------#############

## ��queue��ȡ������������
## got task from thread:queue, output nothing
sub UpdateFile {
    my ($update_list) = @_ ; 
    my $download_method = $method ; 
    my $tid = threads->self->tid ; 

    while ( ! $DONE ) {
        while ( my $a_deploy_path = $queue->dequeue_nb() ) {
            ## lock this file
            Status( $tid => $a_deploy_path ) ;
            my $source = GetValueFromUpdateList($update_list, $a_deploy_path, "source") ; 
            my $file_size = GetValueFromUpdateList($update_list, $a_deploy_path, "file_size") ; 
            my $postfix_command= GetValueFromUpdateList($update_list, $a_deploy_path, "postfix_command") ; 
           
            ## ��data.yaml�л����ڲ�����ָ����--version_control����Ч
            my $version_control = $version_control || "" ;
            if ( $threshold ) {
                if ( $file_size < $threshold )  { 
                    $download_method = "ftp" ; 
                } else {
                    $download_method = "gingko" ; 
                }
            }
            print "Notice: get $source. \n" ; 
            WriteLog("Notice: get $source. \n") ; 
            if ( GetFileWithRetry($source, "$a_deploy_path.tmp","$download_rate" ,"$download_method", "2", "$wget_args", "$gingko_args","") ) { 
                if ( $is_check_md5 ) {
                    if ( CheckMd5("$a_deploy_path.tmp", "$a_deploy_path.md5.tmp") ) {
                        print "Notice: check md5 success. $a_deploy_path \n" ; 
                        WriteLog("Notice: check md5 success. $a_deploy_path \n") ; 
                    } else {
                        print "Fatal: check md5 fail. $source \n" ; 
                        WriteLog("Fatal: check md5 fail. $source \n") ; 
                        $daemon ? next : exit 121 ;
                    }
                }
                if ( UpdateFileOrDir("$a_deploy_path.tmp", "$a_deploy_path","$version_control") and UpdateFileOrDir("$a_deploy_path.md5.tmp", "$a_deploy_path.md5") ) {
                    WriteLog("Notice: update $a_deploy_path ok.\n") ; 
                } else {
                    print "Fatal: update $a_deploy_path fail. \n" ; 
                    WriteLog("Fatal: update $a_deploy_path fail.\n") ; 
                    $daemon ? next : exit 121 ;
                }
                if ( $postfix_command ) {
                    if ( !system("$postfix_command") ) {
                    } else {
                        print "Fatal: run postfix command fail. $postfix_command\n" ; 
                        WriteLog("Fatal: run postfix command fail. $postfix_command\n") ; 
                        $daemon ? next : exit 121 ;
                    }
                }
            } else {
                print "Fatal: get $source fail.\n" ; 
                WriteLog("Fatal: get $source fail.\n") ; 
                $daemon ? next : exit 121 ;
            } 
            sleep(2) ; 
            ## unlock file.
            Status( $tid => '' ) ;
        }
    }
    return 1 ; 
}

## got a ref and return a ref of hash , label -> file_size
sub GetUpdateFileList {
   my ($yaml, $data_type) = @_ ; 
   my @result ; 
   $data_type = $data_type || "static|dynamic" ;
   my $data_type_re = qr/$data_type/ ;    
   for my $label (keys %{$yaml}) {

      my $a_data_ref = $$yaml{"$label"} ; 

      my $type = $$a_data_ref{"type"} ; 

      ## ������Ͳ����ϣ�����������������static����dynamic
      next if ( $type !~ $data_type_re ) ;

      my $source = $$a_data_ref{"source"} ; 
      my $deploy_path = $$a_data_ref{"deploy_path"} ; 
 
      ## ������mfs�м������,���ڶ�̬�����вŴ����������
      if ( $type eq "dynamic" ) {
          if ( $stream eq "up" ) {
              $deploy_path = GenMiddleAddress( $through, $source) ; 
              $deploy_path =~ s/(.*):(.*)/$2/ ; 
          } elsif ( $stream eq "down" ) {
              $source = GenMiddleAddress( $through, $source ) ; 
          }
      }
      my $source_md5 ;
      $source =~ s/\/$// ;
      if( $type eq "dynamic" ) {
          $source = ParseDynamicFile($source) ; 
      }
      if ( not defined $source or $source !~ /\s*/ ) {
         print "Fatal: source is null. $$a_data_ref{'source'}\n" ; 
         WriteLog("Fatal: source is null. $$a_data_ref{'source'}\n") ; 
         $daemon ? next : exit 121 ;
      }

      $source =~ s/\/$// ; 
      $deploy_path =~ s/\/$// ; 
      $source_md5 = $source.".md5" ; 
      
       
      my $local_md5 = $deploy_path.".md5" ; 
      my $local_md5_tmp = $local_md5.".tmp" ; 

      my $local_dir = dirname($deploy_path) ; 
      system("mkdir -p $local_dir") ; 
      ## download md5
      unless ( GetFileWithRetry($source_md5, $local_md5_tmp,"$download_rate", "ftp", 2, "", "" ,"file") ) {
          print "Fatal: get $source_md5 fail.\n" ; 
          WriteLog("Fatal: get $source_md5 fail.\n") ; 
          $daemon ? next : exit 121 ;
      }
      if ( compare("$local_md5" , "$local_md5_tmp") != 0 ) {
         print "Notice: $source update.\n" ; 
         WriteLog("Notice: $source update.\n") ;
         my $file_size = GetRemoteFileSize($source) ; 
         if ( not defined $file_size ) {
             print "Fatal: get file size fail. $source\n" ; 
             WriteLog("Fatal: get file size fail. $source\n") ; 
             $daemon ? next : exit 121 ;
         } else {
             ## put it in data set
             $$a_data_ref{"file_size"} = $file_size ;
             $$a_data_ref{"source"} = $source ; 
             $$a_data_ref{"deploy_path"} = $deploy_path ; 
             push (@result, $a_data_ref) ; 
         }
      } else {
          system("rm -rf $local_md5_tmp") ; 
      }
   }
   unless ( @result ) {
       print "Notice: No file update.\n" ; 
       WriteLog("Notice: No file update.\n") ; 
   }
   return \@result ; 
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

sub TestLabel {
    my ($file) = @_ ; 
    my $hash ; 
    my $fail = 0 ; 
    my $fh = IO::File->new ;
    $fh->open("$file","<") ; 
    while(<$fh>) {
        chomp $_ ; 
        $_ =~ s/\s*$// ; 
        next if ( $_ =~ /^#+/ || $_ =~ /^\s*$/ ) ; 
        if( $_ !~ "^[- ]+") {
            if ( exists $hash->{$_}) {
                $hash->{$_} ++ ; 
            } else {
                $hash->{$_} = 1 ; 
            }   
        }   
    }   
    foreach my $key ( keys %{$hash}) {
        if ( $hash->{$key} != 1 ) { 
            $fail = 1 ; 
            print "Fatal: label $key repeat $hash->{$key}.\n" ;   
        }   
    
    }   
    exit 99 if ( $fail ) ; 
    print "Notice: Testing: label is not repeat.\n" ; 
    WriteLog("Notice: Testing: label is not repeat.\n") ; 
    return 1 ; 
}

sub TestKey {
    my ($file) = @_ ; 
    my $fh = IO::File->new ;
    $fh->open("$file","<") ;
    my $label ;   
    my $check ; 
    for my $line (<$fh>) {
        chomp $line ; 
        next if ( $line =~ /^#+/ || $line =~ /^\s*$/ ); 
        if ( $line =~ m{^([^\s]+):[\s]*$} ) { 
            $label = $1 ; 
            $check = undef ; 
            next ; 
        }   
        if ( $line =~ m{^[\s]+([^:]*):.*} ) { 
            if ( exists $check->{$1} ) { 
                print "Fatal: Testing: label:$label key:$1 repeat.\n" ; 
                WriteLog("Fatal: Testing: label: $label key:$1 repeat.\n") ; 
                return undef ; 
            } else {
                $check->{$1} = 1  ;
            }   
        }   
    }
    return 1 ; 
}


sub TestFormat {
    my ($file) = @_ ; 
    my $yaml = LoadFile("$file") ; 
    for my $label (keys %{$yaml}) {

        my $a_data_ref = $$yaml{"$label"} ; 
  
        for my $key ("type", "source", "deploy_path") {
            unless ( exists $$a_data_ref{"$key"} ) {
                print "Fatal: $label not exist $key\n" ; 
                WriteLog("Fatal: $label not exist $key\n") ; 
                exit 98 ;
            }
        }
    }
    print "Notice: Testing: Format is ok.\n" ; 
    WriteLog("Notice: Testing: Format is ok.\n") ; 
    return 1 ; 
}

sub TestDeployPath {
    my ($file) = @_ ;
    my %deploy_path ; 
    my $yaml = LoadFile("$file") ; 

    for my $label (keys %{$yaml}) {

        my $a_data_ref = $$yaml{"$label"} ;
        if ( exists $deploy_path{"$$a_data_ref{'deploy_path'}"} ) {

            print "Fatal: $$a_data_ref{'deploy_path'} repeat.\n" ; 
            WriteLog("Fatal: $$a_data_ref{'deploy_path'} repeat.\n") ; 
            exit 99 ; 
        } else {
            $deploy_path{"$$a_data_ref{'deploy_path'}"} = 1 ; 
        }
    }


    for my $path (keys %deploy_path) {
        $path = "/$path/" ; 
        for my $test (keys %deploy_path ) {
            if ( $path =~ m{/$test/} and $path ne "/$test/" )  {
                print "Fatal: $path is under $test . \n" ; 
                WriteLog("Fatal: $path is under $test . \n") ; 
                exit 99 ; 
            }
        }
    }

    my $wrong = 0 ; 
    for my $path (keys %deploy_path) {
       if ( $path =~ m{/$} ) {
           $wrong = 1 ; 
           print "Fatal: $path error , Can not end with '/' \n" ; 
           WriteLog("Fatal: $path error , Can not end with '/' \n") ; 
       }
    }
    $wrong and exit 87 ; 

    print "Notice: Testing: Deploy Path ok. \n" ; 
    WriteLog("Notice: Testing: Deploy Path ok. \n") ; 
    return 1 ; 
}

sub Status {
    my $tid = shift ; 
    lock $DIST_THREAD_STATUS ; 
    ## û�в�����Ϊ��ѯֵ��ֻ��Ҫ����Ŀǰ��״ֵ̬��ok��
    return $DIST_THREAD_STATUS{$tid} unless @_ ; 
    ## �в���
    my $status = shift ; 
    if ( $status ) {
        $DIST_THREAD_STATUS{$tid} = $status ; 
    }
    else {
        delete $DIST_THREAD_STATUS{$tid} ; 
    }
    ## ��������
    cond_broadcast $DIST_THREAD_STATUS ; 
}

