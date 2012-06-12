#!/bin/bash

## ������downloaderĿ¼�µ���
function check_run_or_not {
    ## 1. downloader.pid Ϊdonwloader.pl����
    ## 2. readlink -f ����Ϊpwd�ķ����п��ܴ���link������lsof����ʾ����ʵ�ʵ��ļ���
    ## 3. ����lsof�ķ��أ������һ���ֶ���perl����5���ֶ���DIR�����һ���ֶ���downloader������·�����ⷵ����ȷ�����򷵻�ʧ�ܣ�ע��shell��awk�ļ����÷���
    ##    1) -vΪawk���������path
    ##    2) <() Ϊshell�Ľ����滻��������Ϊһ���ļ������awkʹ��
    ##    3) awk �� END{}, �����ı����������еĲ���
    ## ���������Ŀ¼
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
