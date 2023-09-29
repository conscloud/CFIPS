#!/bin/bash
export LANG=zh_CN.UTF-8
Threads=2048 #端口扫描线程数
lines_per_batch=32 #每次读取ip段的行数,避免机器内存不足数据溢出
###############################################################以下脚本内容，勿动#######################################################################
proxygithub="https://ghproxy.com/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"

log() {
    echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

current_line=1
update_gengxinzhi=0
apt_update() {
    if [ "$update_gengxinzhi" -eq 0 ]; then
        sudo apt update
        update_gengxinzhi=$((update_gengxinzhi + 1))
    fi
}

# 检测并安装软件函数
apt_install() {
    if ! command -v "$1" &> /dev/null; then
        log "$1 未安装，开始安装..."
        apt_update
        sudo apt install "$1" -y
        log "$1 安装完成！"
    fi
}

apt_install curl
apt_install zip

# 检测是否已经安装了geoiplookup
if ! command -v geoiplookup &> /dev/null; then
    log "geoiplookup 未安装，开始安装..."
    apt_update
    sudo apt install geoip-bin -y
    log "geoiplookup 安装完成！"
fi

if ! command -v mmdblookup &> /dev/null; then
    log "mmdblookup 未安装，开始安装..."
    apt_update
    sudo apt install mmdb-bin -y
    log "mmdblookup 安装完成！"
fi

# 检测GeoLite2-Country.mmdb文件是否存在
if [ ! -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
    log "文件 /usr/share/GeoIP/GeoLite2-Country.mmdb 不存在。正在下载..."
    
    # 使用curl命令下载文件
    curl -L -o /usr/share/GeoIP/GeoLite2-Country.mmdb "${proxygithub}https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
    
    # 检查下载是否成功
    if [ $? -eq 0 ]; then
        log "下载完成。"
    else
        log "下载失败。脚本终止。"
        exit 1
    fi
fi

if [ -e CloudFlareIP.txt ]; then
  #log "清理旧的CloudFlareIP.txt文件."
  rm -f CloudFlareIP.txt
fi

# 检测temp文件夹是否存在
if [ ! -d "temp" ]; then
    #log "temp文件夹不存在，正在创建..."
    mkdir temp
else
    #log "temp文件夹已存在，正在删除文件..."
    rm -f temp/*  # 删除temp文件夹内的所有文件
fi

gogogo(){
if [ -e "temp/ip0.txt" ]; then
    log "Scan HttpPort..."
    ./Pscan -F temp/ip0.txt -P 80 -T ${Threads} -O "temp/d80.txt" -timeout 1s > /dev/null 2>&1
fi

if [ -e "temp/d80.txt" ]; then
    log "Scan HttpPort Completed."
    awk 'NF' "temp/d80.txt" | sed 's/:80$//' >> "temp/80.txt"
fi

if [ -e "temp/80.txt" ]; then
    log "Scan HttpsPort..."
    ./Pscan -F "temp/80.txt" -P 443 -T ${Threads} -O "temp/d443.txt" -timeout 1s > /dev/null 2>&1
fi

if [ -e "temp/d443.txt" ]; then
    log "Scan HttpsPort Completed."
    awk 'NF' "temp/d443.txt" | sed 's/:443$//' >> "temp/443.txt"
fi

if [ -e "temp/443.txt" ]; then
    log "Test CloudFlareIP"
    python3 TestCloudFlareIP.py
fi
}

# 定义ASN文件夹的路径
asnfolder="./ASN"
# 检测ASN文件夹是否存在
if [ ! -d "$asnfolder" ]; then
    # 如果ASN文件夹不存在，就在当前目录下创建它
    mkdir "$asnfolder"
fi

# 检测ASN文件夹下是否存在txt文件
if ls "$asnfolder"/*.txt 1> /dev/null 2>&1; then
    log "ASN Ready."
else
    # 判断当前目录下ASN.zip文件是否存在
    if [ ! -f "ASN.zip" ]; then
        # 如果ASN.zip文件不存在，使用curl命令下载文件
	log "Download ASN.zip"
        curl -L -o ASN.zip "${proxygithub}https://raw.githubusercontent.com/cmliu/CFIPS/main/ASN.zip"
    fi
    log "unzip ASN.zip"
    # 解压ASN.zip到ASN文件夹
    unzip -q ASN.zip -d "$asnfolder"
    log "ASN Ready."
fi

# 检查ASN文件夹是否存在
if [ -d "$asnfolder" ]; then
  # 获取ASN文件夹中的所有txt文件并将它们存储到数组中
  txtfiles=("$asnfolder"/*.txt)

  # 检查是否存在txt文件
  if [ ${#txtfiles[@]} -gt 0 ]; then
    # 遍历txt文件数组并将文件名作为参数传递给python3脚本
    log "CloudFlareIPScan Starts."
    for txtfile in "${txtfiles[@]}"; do
      # 提取文件名并去掉路径部分
	  asnname=$(basename "$txtfile")
	  log "Scan ASN $asnname"
	  
		while IFS= read -r line; do
			echo "$line" >> ip.txt
			current_line=$((current_line + 1))
			log "Scan CIDR $line"
			if [ "$current_line" -eq "$lines_per_batch" ]; then
				rm -f temp/*
				python3 process_ip.py
				gogogo
				current_line=0
				> ip.txt  # 清空ip.txt文件的内容
			fi
		done < "$txtfile"

		# 处理剩余行数（少于16行的情况）
		if [ "$current_line" -gt 0 ]; then
			rm -f temp/*
			python3 process_ip.py
			gogogo
			> ip.txt  # 清空ip.txt文件的内容
		fi

    done
  else
    log "ASN文件夹中没有txt文件。"
    exit 1  # 退出脚本，1 表示出现了错误
  fi
else
  log "ASN文件夹不存在。"
  exit 1  # 退出脚本，1 表示出现了错误
fi

# 检查CloudFlareIP.txt文件是否存在
if [ -f "CloudFlareIP.txt" ]; then

	# 检测ip文件夹是否存在
	if [ -d "ip" ]; then
		log "开始清理IP地区文件"
		rm -f ip/*
		log "清理IP地区文件完成。"
	else
		log "创建IP地区文件。"
		mkdir -p ip
	fi

log "正在将IP按国家代码保存到ip文件夹内..."
    # 逐行处理CloudFlareIP.txt文件
    while read -r line; do
        ip=$(echo $line | cut -d ' ' -f 1)  # 提取IP地址部分
		result=$(mmdblookup --file /usr/share/GeoIP/GeoLite2-Country.mmdb --ip $ip country iso_code)
		country_code=$(echo $result | awk -F '"' '{print $2}')
		echo $ip >> "ip/${country_code}-443.txt"  # 写入对应的国家文件
    done < CloudFlareIP.txt

# 检测ip.zip文件是否存在，如果存在就删除
if [ -f "ip.zip" ]; then
  rm -f ip.zip
fi

# 将当前目录下的ip文件夹内的所有文件打包成ip.zip
if [ -d "ip" ]; then
  zip -r ip.zip ip/
  log "CloudFlareIPScan Packaging ip.zip Completed!"
else
  log "CloudFlareIPScan Completed!"
fi

else
    log "CloudFlareIP.txt文件不存在，脚本终止。"
    exit 1
fi
