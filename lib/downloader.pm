#!/usr/bin/perl

package downloader ; 
use strict ; 
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK) ; 
$VERSION = '0.1.0' ; 

use Exporter;
our @ISA = qw{ Exporter } ; 
our @EXPORT = qw{ ParseDesFile UpdateFileOrDir GetValueFromUpdateList RemoveUselessFiles GetAllLocalFiles ParseDynamicFile GetFileWithRetry TransScpUrlToFtpUrl GetFtpUrlFileType GetFile CheckMd5 GetRemoteFileSize } ; 
our @EXPORT_OK = qw{ };

use YAML ;
use Data::Dumper ; 
use File::Basename ; 
use File::stat ;
use File::Compare ;
use File::Copy;
use Net::FTP ;
use IO::File ; 

our $download_rate = 10 ; 


## TODO: not support
sub ParseDesFile {
    return 1 ; 
}

sub UpdateFileOrDir {
    my ($source, $dest) = @_ ; 

    if ( -d $dest ) {
        return !system("mv $dest $dest.bak && mv $source $dest && rm -rf $dest.bak") ; 
    } else {
        return !system("mv $source $dest") ; 
    }
}

sub GetValueFromUpdateList {
    my ($update_list, $deploy_path, $key) = @_ ; 
    
    foreach my $a_data ( @{$update_list} ) {
        return $a_data->{"$key"} if $a_data->{"deploy_path"} eq $deploy_path ;
    } 
    return scalar undef ; 
}

## rm fils not in data.yaml
## dist file , yaml not , delete disk file
sub RemoveUselessFiles {
   #GetAllLocalFiles
   return 1 ; 
}

sub GetAllLocalFiles {
   return 1 ; 
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
   while ( $try < 5 ) {
       eval {
          $ftp = FtpConnect("$server") ; 
    
          my @files = $ftp->dir("$path") or die "No such file $path ", $ftp->message ;
       
          foreach my $file (@files) {
              if ( $file =~ /^l.*->\s*(.*)\s*$/ ) {
                  $result = "$server:$1" ; 
              } else {
                  $result = $scp_url ; 
              }
          }
          $ftp->quit;
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
   my ($source, $local_path, $limit, $protocal, $retry, $args) = @_ ; 
   my $return = 0 ; 

   $args= "" if (!$args) ; 
   $limit = "10" if (!$limit) ; 
   $protocal = "gingko" if (!$protocal) ; 
   $retry = 2 if (!$retry) ; 

   while ( $retry ) {
      eval {
          if ( GetFile($source, $local_path, $limit, $protocal, $args) ) {
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
## output : f or d
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
           $ftp = FtpConnect("$server") ; 
           my @files = $ftp->dir($path) ;
           die "No such file: $path" unless (@files) ;
           ## todo : wrong if @files more than 1 element
           $result = "f" if @files == 1 ; 
           $result = "d" if @files > 1 ; 
    
           $ftp->quit;
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


## get file [gingko, ftp]
sub GetFile {
   my ($source, $deploy_path,$limit, $protocal, $args) = @_ ;
   my $cmd ; 
   $limit = $limit || 10 ; 

   if ( $protocal eq "ftp") { 
       $limit = $limit."M" ; 
       my $ftp_url = TransScpUrlToFtpUrl($source) ; 
       my $local_dir = dirname($deploy_path) ; 
       system("mkdir -p $local_dir") ; 
       if ( GetFtpUrlFileType($ftp_url) eq 'd' ) {
           $cmd = "wget -q -r $ftp_url --limit-rate=$limit -P $deploy_path -nH -nd $args" ;
       } elsif ( GetFtpUrlFileType($ftp_url) eq 'f' ) {
           $cmd = "wget --limit-rate=$limit -q $ftp_url -O $deploy_path $args" ;
       } else {
           return undef; 
       }
       return !system($cmd) ;
   }
   elsif ( $protocal eq "gingko" ) {
       $cmd = "gkocp -u 10 -d $limit -l ./gingko.log $source $deploy_path $args" ;
       return !system($cmd) ;
   }
   else {
       return 2 ;
   }
}

## caculate md5 of file
sub CheckMd5 {
    my ( $deploy_path, $md5_file ) = @_ ; 

    my $basename = basename($deploy_path) ; 
    my $dirname  = dirname($deploy_path) ; 
    my $cmd ; 

    if ( -f $deploy_path ) { 
        $cmd = "cd $dirname && md5sum -c $md5_file" ; 
    } elsif ( -d $deploy_path ) {
        $cmd = "cd $deploy_path && cp ../$md5_file ./ && md5sum -c $md5_file" ; 
    }

    return !system("$cmd")  ; 
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
    $log_fh->open("../downloader.log",">>") ; 
    $log_fh->print(GetLogDate() . " " . $msg . "\n") ; 
    $log_fh->close ; 
}

sub GetLogDate {
    my $date = `date +\%F" "\%T` ; 
    chomp $date ; 
    $date = "[$date]" ; 
    return scalar $date ; 
}


1; 
__END__
