# CloudFlareIPScan
运行环境ubuntu20
拉取
``` bash
git clone "https://github.cmliu.net/https://github.com/cmliu/CFIPS.git" && cd CFIPS && chmod +x go.sh process_ip.py TestCloudFlareIP.py Pscan
```

后台运行,日志going.txt
``` bash
nohup ./go.sh > going.txt 2>&1 &
```

后台运行,telegramBot推送通知
``` bash
nohup ./go.sh [telegram UserId] [telegram BotToken] > going.txt 2>&1 &
#例如
nohup ./go.sh 712345678 6123456789:ABCDEFGABCBACBA-XVSDFWERR_FDASDFWER > going.txt 2>&1 &
```

## 文件结构
运行脚本后会自动下载所需文件,所以推荐将脚本放在单独目录下运行
```
CFIPS
 ├─ ASN.zip             #AS库备份
 ├─ go.sh               #脚本主体
 ├─ going.txt           #按上述运行方式会产生going.txt日志文件
 ├─ ip.txt              #单次扫描IP段产生的临时文件
 ├─ process_ip.py       #将CIDR格式的IP段展开的python脚本
 ├─ Pscan               #端口扫描程序
 ├─ TestCloudFlareIP.py #验证是否是CFip的python脚本
 ├─ ip.zip              #扫描结束后自动打包扫描结果ip.zip
 ├─ ASN                 #扫描任务IP库,将需要扫描是IP段和IP写入txt文件放入ASN文件夹后脚本运行就会自动扫描文件夹内的所有IP
 │   ├─ AS132203.txt
 │   ├─ AS31898.txt
 │  ...
 │   └─ AS45102.txt
 ├─ CloudFlareIP        #扫描结果 按AS整理存放
 │   ├─ AS132203.txt
 │   ├─ AS31898.txt
 │  ...
 │   └─ AS45102.txt
 ├─ ip                  #扫描结果 按地区整理存放
 │   ├─ HK-443.txt
 │   ├─ SG-443.txt
 │  ...
 │   └─ KR-443.txt
 └─ temp                #运行时产生的临时文件存放位置
     ├─ ip0.txt
     ├─ 80.txt
    ...
```
