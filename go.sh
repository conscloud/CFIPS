#!/bin/bash
export LANG=zh_CN.UTF-8
perf=1 # 机器性能倍率，爆内存就调低，跑不满机器就调高，默认1
DetailedLog=0 # 打开详细日志设为1
proxygithub="https://ghproxy.com/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"
telegramBotUserId="" # telegram UserId
telegramBotToken="" #telegram BotToken
###############################################################以下脚本内容，勿动#######################################################################
mem=$(free -m | awk 'NR==2{print $4}') # 可用内存
# 计算系数，向上取整
coeff=$(awk -v mem="$mem" -v perf="$perf" 'BEGIN { coeff=int((mem + 511) * perf / 512); if ((mem + 511) * perf % 512 > 0) coeff++; print coeff }')
Threads=$((coeff * 384)) # 端口扫描线程数
lines_per_batch=$((coeff * 3)) # 每次读取ip段的行数,避免机器内存不足数据溢出
if [ $coeff -eq 1 ]; then
    TestUnit=512
else
    TestUnit=$(printf "%.0f" $(echo "scale=2; ($coeff * 512) / $perf" | bc)) # 计算TestCloudFlareIP任务量上限，向下取整
    if [ $TestUnit -gt 2048 ]; then
      TestUnit=2048
    fi
fi
if [ "$mem" -gt 1024 ]; then
    TestCFIPDet=3 #验证次数
else
    TestCFIPDet=2 #验证次数
fi
TestCFIPThreads=$((coeff * 7)) #验证线程
IPs=0
#带有telegramBotUserId参数，将赋值第1参数为telegramBotUserId
if [ -n "$1" ]; then 
    telegramBotUserId="$1"
fi

#带有telegramBotToken参数，将赋值第2参数为telegramBotToken
if [ -n "$2" ]; then
    telegramBotToken="$2"
fi

log() {
    if [ "$DetailedLog" -eq 1 ]; then
        echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
    fi
}

log "RAM: ${mem} MB"
log "COEFF: ${coeff}"
log "TestUnit: ${TestUnit}"
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
        log "$1 Not installed, start installation..."
        apt_update
        sudo apt install "$1" -y
        log "$1 The installation is complete!"
    fi
}

apt_install curl
apt_install zip
apt_install jq

TGmessage(){
#解析模式，可选HTML或Markdown
MODE='HTML'
#api接口
URL="https://api.telegram.org/bot${telegramBotToken}/sendMessage"
if [[ -z ${telegramBotToken} ]]; then
   log "Telegram push notification not configured"
else
   res=$(timeout 20s curl -s -X POST $URL -d chat_id=${telegramBotUserId}  -d parse_mode=${MODE} -d text="$1")
    if [ $? == 124 ];then
      log 'TG_api请求超时,请检查网络是否重启完成并是否能够访问TG'          
    else
      resSuccess=$(echo "$res" | jq -r ".ok")
      if [[ $resSuccess = "true" ]]; then
        log "TG推送成功"
      else
        log "TG推送失败，请检查TG机器人token和ID"
      fi
    fi
fi
}

# 检测是否已经安装了geoiplookup
if ! command -v geoiplookup &> /dev/null; then
    log "geoiplookup Not installed, start installation..."
    apt_update
    sudo apt install geoip-bin -y
    log "geoiplookup The installation is complete!"
fi

if ! command -v mmdblookup &> /dev/null; then
    log "mmdblookup Not installed, start installation..."
    apt_update
    sudo apt install mmdb-bin -y
    log "mmdblookup The installation is complete!"
fi

# 检测GeoLite2-Country.mmdb文件是否存在
if [ ! -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
    log "The file /usr/share/GeoIP/GeoLite2-Country.mmdb does not exist. downloading..."
    
    # 使用curl命令下载文件
    curl -L -o /usr/share/GeoIP/GeoLite2-Country.mmdb "${proxygithub}https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
    
    # 检查下载是否成功
    if [ $? -eq 0 ]; then
        log "Download completed."
    else
        log "Download failed. The script terminates."
        exit 1
    fi
fi

if [ -e ip.txt ]; then
  rm -f ip.txt
fi

# 检测temp文件夹是否存在
if [ ! -d "temp" ]; then
    #log "temp文件夹不存在，正在创建..."
    mkdir temp
else
    #log "temp文件夹已存在，正在删除文件..."
    rm -f temp/*  # 删除temp文件夹内的所有文件
fi

# 检测CloudFlareIP文件夹是否存在
if [ ! -d "CloudFlareIP" ]; then
    mkdir CloudFlareIP
else
    rm -f CloudFlareIP/*
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
	
	inputFile="temp/443.txt"
	lineCount=$(wc -l < "$inputFile")

	# 如果文件行数小于等于TestUnit，直接重命名文件并执行Python脚本
	if [ "$lineCount" -le "$TestUnit" ]; then
		mv "$inputFile" "temp/${asnname}.txt"
		python3 TestCloudFlareIP.py "$TestCFIPDet" "$TestCFIPThreads" "$asnname"

	
	else
		# 如果文件行数大于TestUnit，分割文件并执行Python脚本

		# 计算分割文件的份数，向上取整
		NS=$(( (lineCount + TestUnit - 1) / TestUnit ))

		# 使用awk分割文件
		awk -v lines="$TestUnit" -v ns="$NS" -v prefix="$asnname" '{
			file = "temp/" prefix "-" int((NR-1)/lines) + 1 ".txt"
			print > file
		} ' "$inputFile"


		for i in $(seq 1 $NS); do
			python3 TestCloudFlareIP.py "$TestCFIPDet" "$TestCFIPThreads" "${asnname}-${i}"
		done
		
	fi
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
        #curl -L -o ASN.zip "${proxygithub}https://raw.githubusercontent.com/cmliu/CFIPS/main/ASN.zip"
	curl -L --progress-bar -o ASN.zip "${proxygithub}https://raw.githubusercontent.com/cmliu/CFIPS/main/ASN.zip"
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
	ASNtgtext0=""
	# 遍历数组中的文件名
	for file in "${txtfiles[@]}"; do
		ASN=$(basename "$file" .txt)
		ASNtgtext="$ASN%0A"
		ASNtgtext0="$ASNtgtext0$ASNtgtext"
		# 在这里添加处理文件的逻辑，例如读取文件内容、处理数据等
	done

	TGmessage "CloudFlareIPScan：扫描任务已启动！%0A本次扫描任务列表：%0A$ASNtgtext0"
	StartTime0=$(date "+%s")  # 获取开始时间的Unix时间戳
	nohup ./PMD.sh > /dev/null 2>&1 & # 启动防假死脚本
 
  # 检查是否存在txt文件
  if [ ${#txtfiles[@]} -gt 0 ]; then
    # 遍历txt文件数组并将文件名作为参数传递给python3脚本
    log "CloudFlareIPScan Starts."
    for txtfile in "${txtfiles[@]}"; do
      # 提取文件名并去掉路径部分
	  asnname=$(basename "$txtfile" .txt)
	  IPs=0
	  StartTime=$(date "+%s")  # 获取开始时间的Unix时间戳
	  echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] Scan ASN $asnname"
		while IFS= read -r line; do
			echo "$line" >> ip.txt
			current_line=$((current_line + 1))
			log "Scan CIDR $line"
			if [ "$current_line" -eq "$lines_per_batch" ]; then
				rm -f temp/*
				python3 process_ip.py
       				if [ -f "temp/ip0.txt" ]; then
    				  ip0_line_count=$(wc -l < "temp/ip0.txt")  # 获取文件行数
    				  IPs=$((IPs + ip0_line_count))  # 将行数加到IPs上
				fi
				gogogo
				current_line=0
				> ip.txt  # 清空ip.txt文件的内容
			fi
		done < "$txtfile"

		# 处理剩余行数（少于16行的情况）
		if [ "$current_line" -gt 0 ]; then
			rm -f temp/*
			python3 process_ip.py
   			if [ -f "temp/ip0.txt" ]; then
    			  ip0_line_count=$(wc -l < "temp/ip0.txt")  # 获取文件行数
    			  IPs=$((IPs + ip0_line_count))  # 将行数加到IPs上
			fi
			gogogo
			> ip.txt  # 清空ip.txt文件的内容
		fi
		EndTime=$(date "+%s")  # 获取任务完成时间的Unix时间戳
		# 计算时间差
		TimeDiff=$((EndTime - StartTime))

		# 将时间差转换为时分秒格式
		Hours=$((TimeDiff / 3600))
		Minutes=$(( (TimeDiff % 3600) / 60 ))
		Seconds=$((TimeDiff % 60))

		# 检查指定目录中是否存在符合特定模式的文件
		if ls "CloudFlareIP/${asnname}"*.txt 1> /dev/null 2>&1; then
		    # 将符合要求的txt文件内容写入临时缓存
		    cat "CloudFlareIP/${asnname}"*.txt > temp_cache.txt
		    
		    # 删除符合要求的txt文件
		    rm "CloudFlareIP/${asnname}"*.txt
		    
		    # 创建CloudFlareIP/${asnname}.txt文件并将缓存内容写入
		    cat temp_cache.txt > "CloudFlareIP/${asnname}.txt"
		    rm temp_cache.txt
		
		fi
  
		if [ -f "CloudFlareIP/${asnname}.txt" ]; then
    			ip_line_count=$(wc -l < "CloudFlareIP/${asnname}.txt")  # 获取文件行数
		else
			ip_line_count=0
		fi

		echo "[$(date "+%Y-%m-%d %H:%M:%S")] CloudFlareIPScan completed!"
		echo "                                            ASN: $asnname"
		echo "                                            IPs: $IPs"
		echo "                                            Valid IPs: $ip_line_count"
		echo "                                            Port: 80,443"
		echo "                                            Exec time: $Hours h $Minutes m $Seconds s"
		TGmessage "CloudFlareIPScan：扫描完成！
		ASN：$asnname
		IPs：$IPs
		Valid IP：$ip_line_count
		Port：80,443
		Exec time：$Hours时$Minutes分$Seconds秒"
    done
  else
    log "There is no txt file in the ASN folder."
    exit 1  # 退出脚本，1 表示出现了错误
  fi
else
  log "ASN folder does not exist."
  exit 1  # 退出脚本，1 表示出现了错误
fi

if [ -e CloudFlareIP.txt ]; then
  #log "清理旧的CloudFlareIP.txt文件."
  rm -f CloudFlareIP.txt
fi
cat CloudFlareIP/*.txt > CloudFlareIP.txt

# 检查CloudFlareIP.txt文件是否存在
if [ -f "CloudFlareIP.txt" ]; then

	# 检测ip文件夹是否存在
	if [ -d "ip" ]; then
		#log "开始清理IP地区文件"
		rm -f ip/*
		#log "清理IP地区文件完成。"
	else
		#log "创建IP地区文件。"
		mkdir -p ip
	fi

	#log "正在将IP按国家代码保存到ip文件夹内..."
    # 逐行处理CloudFlareIP.txt文件
    while read -r line; do
        ip=$(echo $line | cut -d ' ' -f 1)  # 提取IP地址部分
		result=$(mmdblookup --file /usr/share/GeoIP/GeoLite2-Country.mmdb --ip $ip country iso_code)
		country_code=$(echo $result | awk -F '"' '{print $2}')
		echo $ip >> "ip/${country_code}-443.txt"  # 写入对应的国家文件
    done < CloudFlareIP.txt

	if [ -e "ip/-443.txt" ]; then
		mv "ip/-443.txt" "ip/null-443.txt"
	fi
	# 定义数组
	Codetxtfiles=("ip"/*.txt)
	ENDtgtext0=""

	# 遍历数组中的文件名
	for file in "${Codetxtfiles[@]}"; do
		# 使用basename命令提取文件名部分（不包括路径和扩展名）
		CC=$(basename "$file" .txt)
		CClineCount=$(wc -l < "$file")
		ENDtgtext="	地区：$CC  	可用IP：$CClineCount%0A"
		ENDtgtext0="$ENDtgtext0$ENDtgtext"
		# 在这里添加处理文件的逻辑，例如读取文件内容、处理数据等
	done

	EndTime0=$(date "+%s")  # 获取任务完成时间的Unix时间戳
	# 计算时间差
	TimeDiff0=$((EndTime0 - StartTime0))

	# 将时间差转换为时分秒格式
	Hours0=$((TimeDiff0 / 3600))
	Minutes0=$(( (TimeDiff0 % 3600) / 60 ))
	Seconds0=$((TimeDiff0 % 60))
	TGmessage "CloudFlareIPScan：扫描任务已全部完成！%0A本次扫描任务汇总：%0A$ENDtgtext0%0A总计用时：$Hours0时$Minutes0分$Seconds0秒"

	# 检测ip.zip文件是否存在，如果存在就删除
	if [ -f "ip.zip" ]; then
	  rm -f ip.zip
	fi

	# 将当前目录下的ip文件夹内的所有文件打包成ip.zip
	if [ -d "ip" ]; then
	  zip -r ip.zip ip/*
	  log "CloudFlareIPScan Packaging ip.zip Completed!"
	else
	  log "CloudFlareIPScan Completed!"
	fi

else
    log "The CloudFlareIPScan result is empty, please add the IP segment."
    exit 1
fi
