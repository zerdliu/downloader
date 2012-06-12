#!/bin/bash

## 必须在downloader目录下调用
function check_run_or_not {
    ## 1. downloader.pid 为donwloader.pl生成
    ## 2. readlink -f 是因为pwd的返回有可能带有link，但是lsof则显示的是实际的文件名
    ## 3. 根据lsof的返回，如果第一个字段是perl，第5个字段是DIR，最后一个字段是downloader启动的路径，这返回正确，否则返回失败，注意shell和awk的几个用法：
    ##    1) -v为awk传入变量：path
    ##    2) <() 为shell的进程替换，返回作为一个文件句柄给awk使用
    ##    3) awk 的 END{}, 所有文本处理完后进行的操作
    ## 到达程序主目录
    cd ../../
    if [ -f downloader.pid ] ; then
        awk -v path=$(readlink -f `pwd`) '{ if ( $NF == path && $1 == "perl" && $5 == "DIR" ) result=$NF }END{ if (result) {exit 0} else {exit 23} }' <(/usr/sbin/lsof -p `cat downloader.pid`)
    else 
        return 11
    fi
}


if [ $# -ne 1 ] ; then
    echo "args wrong : start | stop "
    exit 11
fi

check_run_or_not
return_status=$?
if [ X$1 == "Xstart" ] ; then
    if [ $return_status -eq 0 ] ; then 
        echo "Notice: downloader.pl is running."
    else 
        echo "Fatal: downloader.pl not run."
    fi
    exit $return_status
elif [ X$1 == "Xstop" ] ; then

    if [ $return_status -eq 0 ] ; then 
        echo "Fatal: downloader.pl is running."
        exit 23
    else 
        echo "Notice: downloader.pl not run."
        exit 0
    fi
else 
    echo "args wrong : start | stop"
    exit 11
fi
