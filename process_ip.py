import ipaddress

# 清空或创建ip0.txt文件
with open("temp/ip0.txt", "w") as output_file:
    pass

# 函数：展开CIDR格式的IP地址范围并保存到ip0.txt
def expand_cidr(cidr):
    ip_range = ipaddress.IPv4Network(cidr, strict=False)
    with open("temp/ip0.txt", "a") as output_file:
        for ip in ip_range:
            output_file.write(str(ip) + "\n")

# 读取ip.txt文件的每一行
with open("ip.txt", "r") as input_file:
    for line in input_file:
        line = line.strip()  # 移除额外的空白字符
        # 判断行是否包含IP段
        if "/" in line:
            expand_cidr(line)
        else:
            # 直接将IP追加到ip0.txt
            with open("temp/ip0.txt", "a") as output_file:
                output_file.write(line + "\n")

#print("处理完成，结果保存在temp/ip0.txt中")
