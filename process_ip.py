import sys
import os
import ipaddress

# 函数：展开CIDR格式的IP地址范围并保存到ip0.txt
def expand_cidr(cidr, output_file):
    ip_range = ipaddress.IPv4Network(cidr, strict=False)
    for ip in ip_range:
        output_file.write(str(ip) + "\n")

# 检查是否有命令行参数
if len(sys.argv) != 2:
    print("请提供一个txt文件名作为参数")
    sys.exit(1)

# 获取命令行参数（文件名）
txt_file = sys.argv[1]

# 构建文件路径
file_path = os.path.join("ASN", txt_file)

# 检查文件是否存在
if not os.path.exists(file_path):
    print(f"找不到文件: {file_path}")
    sys.exit(1)

# 打开文件进行读取
try:
    with open(file_path, "r") as input_file, open("temp/ip0.txt", "w") as output_file:
        for line in input_file:
            line = line.strip()
            # 假定每行都是一个CIDR格式的IP段
            expand_cidr(line, output_file)

    #print("处理完成，结果保存在temp/ip0.txt中")
except Exception as e:
    print(f"发生错误: {str(e)}")
