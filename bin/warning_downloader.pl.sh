#!/bin/bash

program=`basename $0`
run_program=`echo $program|sed 's/^warning_\(.*\)\.sh$/\1/'`
run_program_path=/home/work/${run_program}/

retry_num=1
log_fname="./status/${run_program}_restartlog"
mobile_list="15811374363 15801462951"       
mail_list="im-op@baidu.com"   
rd_mobile_list="15811374363 15801462951" 	
rd_mail_list="im-op@baidu.com" 
run_program_wflog=./log/${run_program}.log.wf
restart_bak_wflog_name=${run_program}.log.wf.restart.`date +%Y%m%d%H%M%S`	
restart_bak_wflog_path=~/opdir/tmp/			


# check core file and wf log ++++ 

ls ./core.* &> /dev/null
if [ $? -eq 0 ] && [ $1 -eq 1 ]  # there is core file under current directory, warning
then
  # check core file
  msg_title="FATAL: [`date +%Y-%m-%d\ %T`]: $run_program: there is core file under [`hostname`]:`pwd`"
  mkdir -p `dirname $log_fname`
  echo "$msg_title" >> $log_fname
 
  # backup wf log
  mkdir -p $restart_bak_wflog_path
  tail -n 2000 $run_program_wflog > $restart_bak_wflog_path/$restart_bak_wflog_name
  
  chmod 777 ./core.*
  corefiles=`ls ./core.*`
  for corefile in $corefiles
  do
    corefile=`basename $corefile`
    msg_text="${msg_text}wget ftp://${HOSTNAME}${PWD}/$corefile\n"
  done 
  msg_text="${msg_text}wget ftp://${HOSTNAME}$restart_bak_wflog_path/$restart_bak_wflog_name\n"
  
  echo -e "${msg_text}" | mail -s "$msg_title" $rd_mail_list
  
  for mobile in $rd_mobile_list
  do 
    gsmsend -s emp01.baidu.com:15003 -s emp02.baidu.com:15003 $mobile@"$msg_title"
  done 

fi


# write log and send warning message

msg="FATAL: [`date +%Y-%m-%d\ %T`]: $run_program: [`hostname`]$run_program restarted, ${1} times"

mkdir -p `dirname $log_fname`
echo "$msg" >> $log_fname

echo "" | mail -s "$msg" $mail_list

for mobile in $mobile_list
do 
	gsmsend -s emp01.baidu.com:15003 -s emp02.baidu.com:15003 $mobile@"$msg"
done


# kill
if [ "$retry_num" -ge 0 ]
then
	if [ "$1" -gt "$retry_num" ]  
	then
        cd ${run_program_path}/bin/ && bash ./${run_program}_control stop
	fi
fi

