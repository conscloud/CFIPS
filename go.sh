#!/bin/bash
###############################################################以下脚本内容，勿动#######################################################################
proxygithub="https://ghproxy.com/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"

# 检测temp文件夹是否存在
if [ ! -d "temp" ]; then
    echo "temp文件夹不存在，正在创建..."
    mkdir temp
else
    echo "temp文件夹已存在，正在删除文件..."
    rm -f temp/*  # 删除temp文件夹内的所有文件
fi

if [ -e "ip.txt" ]; then
    echo "开始整理IP文件库"
    python3 process_ip.py
else
    echo "ip.txt 文件不存在，脚本结束。"
    exit 1  # 退出脚本，1 表示出现了错误
fi

if [ -e "temp/ip0.txt" ]; then
    echo "扫描IP文件库80端口开始..."
    ./Pscan -F temp/ip0.txt -P 80 -T 128 -O temp/d80.txt -timeout 1s > /dev/null 2>&1
else
    echo "无有效IP内容，脚本终止。请重新编写ip.txt文件"
    exit 1  # 终止脚本，1 表示出现了错误
fi

if [ -e "temp/d80.txt" ]; then
    echo "扫描IP文件库80端口完成."
    awk 'NF' temp/d80.txt | sed 's/:80$//' >> temp/80.txt
else
    echo "无IP开启80端口，脚本终止。请增加ip.txt文件内IP数"
    exit 1  # 终止脚本，1 表示出现了错误
fi

if [ -e "temp/80.txt" ]; then
    echo "扫描IP文件库443端口开始..."
    ./Pscan -F temp/80.txt -P 443 -T 128 -O temp/d443.txt -timeout 1s > /dev/null 2>&1
else
    echo "无IP开启443端口，脚本终止。请增加ip.txt文件内IP数"
    exit 1  # 终止脚本，1 表示出现了错误
fi

if [ -e "temp/d443.txt" ]; then
    echo "扫描IP文件库443端口完成."
    awk 'NF' temp/d443.txt | sed 's/:443$//' >> temp/443.txt
else
    echo "无IP开启443端口，脚本终止。请增加ip.txt文件内IP数"
    exit 1  # 终止脚本，1 表示出现了错误
fi

echo "开始验证CloudFlareIP"
python3 TestCloudFlareIP.py
