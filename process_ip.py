import sys
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

# 检查是否有命令行参数
if len(sys.argv) != 2:
    print("请提供一个CIDR格式的IP段作为参数")
    sys.exit(1)

# 获取命令行参数并展开
cidr_argument = sys.argv[1]
expand_cidr(cidr_argument)

print("处理完成，结果保存在temp/ip0.txt中")
