import requests
from concurrent.futures import ThreadPoolExecutor

# 读取ip.txt中的每个IP地址并执行测试
def test_ip(ip):
    max_retries = 3
    retries = 0
    while retries < max_retries:
        try:
            response = requests.get(f"http://{ip}", headers={"Host": "testcfip.ssrc.cf"}, timeout=1, allow_redirects=False)
            # print(response.text)
            # 检查是否是301跳转并且Server是cloudflare
            if response.status_code == 301 and 'cloudflare' in response.headers.get('Server', '').lower():
                print(f"IP {ip} 是 Cloudflare 服务器.")
                with open('CloudFlareIP.txt', 'a') as cf_file:
                    cf_file.write(f"{ip}\n")
            break  # 如果测试成功，退出循环
        except Exception as e:
            print(f"IP {ip} 第 {retries + 1} 次测试出错: {str(e)}")
            retries += 1
    else:
        print(f"IP {ip} 测试失败，已尝试 {max_retries} 次。")

print("开始测试。")

# 使用多线程执行测试
with ThreadPoolExecutor(max_workers=128) as executor:  # 这里设置线程池的最大线程数
    with open('temp/443.txt', 'r') as ip_file:
        ips = [ip.strip() for ip in ip_file]
        executor.map(test_ip, ips)

print("测试完成。Cloudflare IP 地址已写入 CloudFlareIP.txt 文件。")
