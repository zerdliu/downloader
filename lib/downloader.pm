#!/usr/bin/perl

package downloader ; 
use strict ; 
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK) ; 
$VERSION = '0.1.0' ; 

use Exporter;
our @ISA = qw{ Exporter } ; 
our @EXPORT = qw{ UpdateFileOrDir GetValueFromUpdateList ParseDynamicFile GetFileWithRetry CheckMd5 GetRemoteFileSize WriteLog CreatPidFile GenMiddleAddress} ; 
our @EXPORT_OK = qw{ };

use Data::Dumper ; 
use File::Basename ; 
use File::stat ;
use File::Compare ;
use File::Copy;
use Net::FTP ;
use IO::File ; 
use Digest::MD5 ;

sub CreatPidFile {                                                   
    my ($pid_file) = @_ ;                                            
                                                                         
    if ( -e $pid_file ) {                                        
                                                                         
        my $fh = IO::File->new($pid_file) || return ;                
        my $pid = <$fh> ;                                            
        $fh->close ;                                                 
                                                                         
        if ( kill 0 => $pid ) {                                      
            return 0 ;                                               
        }                                                        
        else {                                                   
            unlink $pid_file || return ;                         
        }                                                            
    }                                                                
                                                                         
    my $fh = IO::File->new($pid_file, O_WRONLY|O_CREAT|O_EXCL,0644) || return ;
    $fh->print("$$") ;                                               
    $fh->close ; 
    return 1 ;  
}   

sub UpdateFileOrDir {
    my ($source, $dest, $version_control) = @_ ;

    if ( $version_control eq "yes" ) {
        my $version = get_link_version($dest)  ;
        return !system("rm -rf $dest.$version && mv $source $dest.$version && rm -rf $dest && ln -s $dest.$version $dest && cp $dest.md5.tmp $dest.$version.md5") ;
    } else {
            
        if ( -d $dest ) {
            return !system("mv $dest $dest.bak && mv $source $dest && rm -rf $dest.bak") ;
        } else {
            return !system("mv $source $dest") ;
        }
        
    }
 
}

sub get_link_version {
    my ( $link_path ) = @_ ;
    my $version ;
    my $dest ; 
    if ( -l $link_path ) {
        my $dest = readlink $link_path ;
        $dest =~ m{.*\.(\d+)$} ;
        $version = $1 + 1;
    } else {
        $version = 1 ;
    }
  
    return $version ;
}

sub GetValueFromUpdateList {
    my ($update_list, $deploy_path, $key) = @_ ; 
    
    foreach my $a_data ( @{$update_list} ) {
        return $a_data->{"$key"} if $a_data->{"deploy_path"} eq $deploy_path ;
    } 
    return scalar undef ; 
}

## parse link to file  :  file -> file.4  ; input scp_url , output scp_url
sub ParseDynamicFile {
   my ($scp_url)=@_;
   my $ftp ;
   my $result ; 

   my @scp_url = split(/:/, $scp_url) ;
   my $server = $scp_url[0] ;
   my $path = $scp_url[1] ;

   my $try = 0 ;
   my @files ; 
   while ( $try < 5 ) {
       eval {

          $ftp = FtpConnect("$server") ; 
          @files = $ftp->dir("$path") or die "No such file $path ", $ftp->message ;   
          $ftp->quit;
 
          @files = `lftp $server -e "set net:timeout 1;set net:max-retries 20;set net:reconnect-interval-base 5;set net:reconnect-interval-multiplier 1 ; ls -d $path ; quit"`; 
          die "No such file or dir. $server:$path\n" if not defined @files ; 
          foreach my $file (@files) {
              if ( $file =~ /^l.*->\s*(.*)\s*$/ ) {
                  $result = "$server:$1" ; 
              } else {
                  $result = $scp_url ; 
              }
          }
       } ; 
       return $result unless $@ ; 
       if ( $@ =~ /No such file/) {
           WriteLog("FATAL: $@") ; 
           print $@ ; 
           return undef ; 
       } else {
           WriteLog("WARNING: $@") ; 
           print $@ ; 
       } 
       sleep(4) ;
       $try ++ ;  
   }
   return $result ;  
}

## get file , many times 
sub GetFileWithRetry {
   my ($source, $local_path, $limit, $protocal, $retry, $wget_args, $gingko_args, $file_type) = @_ ; 
   my $return = 0 ; 

   $wget_args= "" if (!$wget_args) ; 
   $gingko_args= "" if (!$gingko_args) ; 
   $limit = "10" if (!$limit) ; 
   $protocal = "gingko" if (!$protocal) ; 
   $retry = 2 if (!$retry) ; 

   while ( $retry ) {
      eval {
          if ( GetFile($source, $local_path, $limit, $protocal, $wget_args, $gingko_args, $file_type) ) {
              $return = 1 ; 
              last ; 
          } else {
              die "Get $source Fail. $@" ; 
          }	  
      }; 
      if ( $@ ) {
          WriteLog("Warning: $@") ; 
          print $@ ; 
      }
      $retry -- ; 
      sleep(10) ; 
   }
   return $return ; 
}

## server:/path -> ftp://server/path
sub TransScpUrlToFtpUrl {
    my ($scp_url) = @_ ; 

    my @ftp_url = split(/:/, $scp_url) ;
    my $ftp_url = "ftp://".$ftp_url[0].$ftp_url[1] ;

    return $ftp_url ; 
}

## input  : ftp url 
## output : file or dir
sub GetFtpUrlFileType {
    my ($ftp_url) = @_ ; 
    my $ftp ; 
    $ftp_url =~ m{^ftp://([^\/]*)(.*)} ; 
    my $server = $1 ; 
    my $path = $2 ; 
    my $result ; 
    #print "$server | $path\n" ; 

    my $try = 0 ;
    while ( $try < 5 ) {
        eval {
           my $long_output = `lftp $server -e "set net:timeout 1;set net:max-retries 20;set net:reconnect-interval-base 5;set net:reconnect-interval-multiplier 1 ; ls -d $path ; quit"`; 
           die "No such file $ftp_url" unless $long_output ; 
           chomp $long_output ; 
           $long_output =~ m{^(.)} ; 
           ## todo : wrong if @files more than 1 element
           $result = "file" if $1 eq "-" ; 
           $result = "dir" if $1 eq "d" ; 
    
        } ; 
        return $result unless $@ ; 

        if ( $@ =~ /No such file/) {
            WriteLog("FATAL: $@") ; 
            print $@ ; 
            return undef ; 
        } 
        $try ++ ;
        sleep(2) ; 
    } 
    return $result ;   
}


## get file [gingko, ftp]
sub GetFile {
   my ($source, $deploy_path,$limit, $protocal, $wget_args, $gingko_args,$file_type) = @_ ;
   my $cmd ; 
   $limit = $limit || 10 ; 

   if ( $protocal eq "ftp") { 
       $limit = $limit."M" ; 
       my $ftp_url = TransScpUrlToFtpUrl($source) ; 
       my $local_dir = dirname($deploy_path) ; 
       system("mkdir -p $local_dir") ; 
       if( $file_type eq "" ) {
           $file_type = GetFtpUrlFileType($ftp_url);
       }
       my $cut_dirs=0;
       ++$cut_dirs while($ftp_url =~ m/\//g);
       $cut_dirs = $cut_dirs - 2;
       if ( $file_type eq "dir" ) {
           system("rm -rf $deploy_path") ; 
           system("mkdir -p $local_dir") ; 
           $cmd = "wget -q -l0 -nH --cut-dirs=$cut_dirs --limit-rate=$limit  $wget_args -r $ftp_url -P $deploy_path";
       } elsif ( $file_type eq "file" ) {
           $cmd = "wget -q --limit-rate=$limit  $wget_args $ftp_url -O $deploy_path";
       } else {
           return undef; 
       }
       return !system($cmd) ;
   }
   elsif ( $protocal eq "gingko" ) {
       $cmd = "gkocp -u 50 -s 10 -d $limit -l ./gingko.log $source $deploy_path $gingko_args" ;
       return !system($cmd) ;
   }
   else {
       return 2 ;
   }
}

## input a ftp url , output file size (integer) 
sub GetRemoteFileSize {
   my ($scp_url)=@_;  
   my $ftp ;
   my $size ;

   my @scp_url = split(/:/, $scp_url) ;
   my $server = $scp_url[0] ; 
   my $path = $scp_url[1] ; 

   my $try = 0 ;
   while ( $try < 5 ) {
       eval {
	  $ftp = FtpConnect("$server") ;  
          my @files = $ftp->ls("$path") ;
          die "No such file: $scp_url" unless (@files) ;
          foreach my $file (@files) {
              $size += ( $ftp->size("$file") || 0 ) ;
          }
          $ftp->quit;
       } ;  
    
       return $size unless $@ ; 
       if ( $@ =~ /No such file/) {
           WriteLog("FATAL: $@") ; 
	   print $@ ; 
           return undef ; 
       } else {
           WriteLog("WARNING: $@") ; 
	   print $@ ; 
           $size = undef ; 
       } 
       sleep(4) ;
       $try ++ ;
   }
   return $size ; 
}

sub FtpConnect {
   my ($server) = @_ ; 
   my $ftp ; 
   $ftp = Net::FTP->new("$server", Debug => 0, Timeout => 500 ) or die "Cannot connect to $server: $@" ;
   $ftp->login("anonymous",'-anonymous@') or die "Cannot login:", $ftp->message ;
   $ftp->binary() or die "Cannot binary:", $ftp->message ;
   return $ftp ; 
}

sub WriteLog {
    my ($msg) = @_ ; 
    chomp $msg ;  
    my $log_fh = IO::File->new ; 
    $log_fh->open("./downloader.log",">>") ; 
    $log_fh->print(GetLogDate() . " " . $msg . "\n") ; 
    $log_fh->close ; 
}

sub GetLogDate {
    my $date = `date +\%F" "\%T` ; 
    chomp $date ; 
    $date = "[$date]" ; 
    return scalar $date ; 
}

sub CheckMd5 {
    my ($item,$md5_file) = @_ ;

    if ( -f $item ) {
        my $ret = CheckFileMd5($item, $md5_file) ; 
        return $ret ; 
    } elsif ( -d $item ) {
        if ( $md5_file =~ m{^/} ) {
        } else {
            $md5_file = $ENV{"PWD"}/$md5_file ; 
        }
        return !system("cd $item && md5sum -c $md5_file &>/dev/null") ; 
    } else {
        print "Fatal: $item not a file or directory\n" ; 
        WriteLog("Fatal: $item not a file or directory\n") ;  
        return undef ; 
    }
}

sub CheckFileMd5 {
    my ($file,$md5_file) = @_ ;
    my $md5 ; 

    my $file_fh = IO::File -> new("$file") ;
    my $ctx = Digest::MD5 -> new ;

    $ctx -> addfile($file_fh) ;
    my $digest = $ctx -> hexdigest ;
    $file_fh -> close ; 

    $md5 = `head -n1 $md5_file | awk '{print \$1} '` ; 
    chomp $md5 ; 
    $digest eq $md5 ? return 1 : return undef ; 
}

sub GenMiddleAddress {
    my ( $through_addr, $source_addr) = @_ ;
    my $middle_address = $through_addr . "/" . basename($source_addr) . "/" . GenMd5Hash($source_addr) . "/" . basename($source_addr) ; 

    return $middle_address ; 
}

sub GenMd5Hash {
    my ( $data ) = @_ ; 
    my $ctx = Digest::MD5->new;
    $ctx->add($data);
    my $digest = $ctx->hexdigest;
    print $digest . "\n" ; 
    return $digest ; 
}

1; 
__END__
