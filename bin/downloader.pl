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
our $method = "gingko" ; 
our $version = "1.0.0" ; 
our $self_name = __FILE__ ; 
our $show_version = sub { print $self_name." : ".$version."\n" ; exit  } ; 
our $threshold = 0 ; 
our $data_type = "" ; 
our $download_rate = 10 ; 

my $usage = <<END 
usage: $self_name [options]

  options are:
    -? -h --help          show this message
    -v --version          show version
    -d --daemon           run as daemon
    -i --interval         sleep time between each instance when run as daemon
    -f --yaml-file        input yaml file
    -t --test             run as test , check yaml file and file exist or not
    -p --parallel         parallel number when download files 
    -m --method           get file method: ftp|gingko
    --data-type           static|dynamic
    --threshold           threshold for ftp or gingko . below threshold use ftp , above threshold use gingko, default:0 , unit: M
    -l --download-rate    limit rate when download. default:10 , unit:M
END
;
my $cmd_config = GetOptions(
    "parallel|p=i" => \$parallel_num ,
    "daemon|d!" => sub { $daemon = 1 } ,
    "interval|i=i" => \$interval, 
    "method|m=s" => \$method, 
    "yaml-file|f=s" => \$yaml_file, 
    "test|t!" => sub { $testing = 1 }, 
    "help|?|h!" => sub{ print $usage ; exit  }, 
    "version|v!" => $show_version , 
    "data-type=s" => \$data_type , 
    "l|download-rate=i" => \$download_rate ,
    "threshold=i" => \$threshold ,
) ;

$threshold = $threshold * 1024 * 1024 ; 

my $yaml ; 
our $queue ; 
our $DONE :shared = 0 ; 

do {
    ## 解析配置文件，存储成通用数据结构
    ## trans des to yaml
    $yaml = ParseDesFile("$yaml_file") ;  ## useless now
    $yaml = LoadFile("$yaml_file") ; 
    #print Dumper($yaml) ; 
    ## 把更新的列表放入queue
    
    $queue = Thread::Queue->new() ;
    ## 标识线程是否退出
    $DONE = 0 ;
    
    my $update_list = GetUpdateFileList($yaml, $data_type) ; 
    ## 填充队列
    my @sorted_update_list = sort { $a->{"file_size"} <=> $b->{"file_size"} } @{$update_list} ; 
    #print Dumper \@sorted_update_list ; 
    foreach my $aData ( @sorted_update_list ) {
        #print Dumper $aData ; 
        #print $aData->{"deploy_path"}."\n" ; 
        $queue->enqueue($$aData{"deploy_path"}) unless $testing ;
    } 
    
    ## 生成线程
    for ( 1..$parallel_num ) {
        threads->new(\&UpdateFile, \@sorted_update_list) ;
    }
    
    ## 等待直到队列中的任务完成
    while ( $queue->pending ) {;}
    $DONE = 1 ;
    
    ## 回收线程
    for my $thr (threads->list()) {
        $thr->join();
    }
    print "sleep \n " ; 
} while ( $daemon and (sleep $interval) ) ; 
#######----------------------------------function-----------------------------#############3333

## 从queue中取数据下载任务
## got task from thread:queue, output nothing
sub UpdateFile {
    my ($update_list) = @_ ; 

    while ( ! $DONE ) {
        while ( my $a_deploy_path = $queue->dequeue_nb() ) {
            #print Dumper $a_deploy_path ;
            my $source = GetValueFromUpdateList($update_list, $a_deploy_path, "source") ; 
            #print "source : $source \n" ; 
            my $file_size = GetValueFromUpdateList($update_list, $a_deploy_path, "file_size") ; 
            if ( $file_size < $threshold )  { 
                $method = "ftp" ; 
            }
            if ( GetFileWithRetry($source, "$a_deploy_path.tmp","$download_rate" ,"$method") and UpdateFileOrDir("$a_deploy_path.tmp", "$a_deploy_path") and UpdateFileOrDir("$a_deploy_path.md5.tmp", "$a_deploy_path.md5" )) {
                ;
            } else {
		WriteLog("Update File fail -- $a_deploy_path") ; 
            } 
            sleep(2) ; 
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

      ## 如果类型不符合，则跳过。即仅下载static或者dynamic
      next if ( $type !~ $data_type_re ) ;

      my $source = $$a_data_ref{"source"} ; 
      my $deploy_path = $$a_data_ref{"deploy_path"} ; 
      my $source_md5 ; 

      print "before parse $source\n" ; 
      $source = ParseDynamicFile($source) ; 
      $source =~ s/\/$// ; 
      $deploy_path =~ s/\/$// ; 
      print "after parse $source\n" ; 
      $source_md5 = $source.".md5" ; 
      
      if ( $source and $source =~ /\s*/ ) {
      } else {
          WriteLog("source is null") ; 
          next ; 
      } 
       
      my $local_md5 = $deploy_path.".md5" ; 
      my $local_md5_tmp = $local_md5.".tmp" ; 

      my $local_dir = dirname($deploy_path) ; 
      system("mkdir -p $local_dir") ; 
      ## download md5
      GetFileWithRetry($source_md5, $local_md5_tmp,"$download_rate","ftp") ; 
      #print "past:$local_md5 ; now:$local_md5_tmp\n" ; 
      if (compare("$local_md5" , "$local_md5_tmp") != 0 ) {
         my $file_size = GetRemoteFileSize($source) ; 
         ## put it in data set
         $$a_data_ref{"file_size"} = $file_size ;
         $$a_data_ref{"source"} = $source ;  
         $$a_data_ref{"deploy_path"} = $deploy_path ;  
         push (@result, $a_data_ref) ; 
      }
   }
   #print Dumper \@result ; 
   return \@result ; 
}
