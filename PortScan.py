import socket
import sys
import threading
import argparse
import time

def getPortBanner(ip, p):
    try:
        port = int(p)
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        if port == 3306 or port == 22 or port == 23 or port == 1521:
            s.settimeout(5)
        else:
            s.settimeout(0.2)
        s.connect((ip, port))
        s.send(b'HELLO\r\n')
        # print(ip + "\t" + p + " Open")
        # print(ip + "\t" + p + " Open\t" + s.recv(1024).split(b'\r\n')[0].strip(b'\r\n').decode())
        print(ip)
        # 打开文件并追加IP地址
        with open(str(port) + ".txt", "a") as file:
            file.write(ip + "\n")  # 加上换行符以区分不同的IP地址
    except Exception as e:
        # print(e)
        pass
    finally:
        s.close()

def GetPortsBanner(ip, ports):
    for p in ports:
        getPortBanner(ip, str(p))

def CscanPortBanner(ip, ports):
    if '/24' in ip:
        #print('ip/24: ' + ip)
        ipc = (ip.split('.')[:-1])
        for i in range(1, 256):
            ip = ('.'.join(ipc) + '.' + str(i))
            threading._start_new_thread(GetPortsBanner, (ip, ports,))
            time.sleep(0.1)
    else:
        GetPortsBanner(ip, ports)

def BscanPortBanner(ip, ports):
    if '/16' in ip:
        #print('ip/16: ' + ip)
        ipc = (ip.split('.')[:-2])
        for i in range(1, 256):
            ip = ('.'.join(ipc) + '.' + str(i) + '.0/24')
            CscanPortBanner(ip, ports)

def AscanPortBanner(ip, ports):
    if '/8' in ip:
        #print('ip/8: ' + ip)
        ipc = (ip.split('.')[:-3])
        for i in range(1, 256):
            ip = ('.'.join(ipc) + '.' + str(i) + '.0/16')
            BscanPortBanner(ip, ports)

if __name__ == '__main__':
    # print('K8PortScan 1.0')
    parser = argparse.ArgumentParser()
    parser.add_argument('-ip', help='IP or IP/24')
    parser.add_argument('-f', dest="ip_file", help="ip.txt ip24.txt ip16.txt ip8.txt")
    parser.add_argument('-p', dest='port', type=str, help="Example: 80 80-89 80,443,3306,8080")
    args = parser.parse_args()
    ip = args.ip
    tmpPorts = args.port
    ipfile = args.ip_file
    if ip == None and ipfile == None:
        print('Error: ip or ipfile is Null!')
        print('Help: -h or --help')
        sys.exit(1)
    if tmpPorts:
        if ',' in tmpPorts:
            ports = tmpPorts.split(',')
        elif '-' in tmpPorts:
            ports = tmpPorts.split('-')
            tmpports = []
            [tmpports.append(i) for i in range(int(ports[0]), int(ports[1]) + 1)]
            ports = tmpports
        else:
            ports = [tmpPorts]
    else:
        print('Default Ports')
        ports = [80, 443]
    if ipfile != None:
        iplist = []
        with open(str(ipfile)) as f:
            while True:
                line = str(f.readline()).strip()
                if line:
                    iplist.append(line)
                else:
                    break
        if ipfile == 'ip24.txt':
            #print('Scan iplist/24')
            for ip in iplist:
                CscanPortBanner(ip + '/24', ports)
        elif ipfile == 'ip16.txt':
            #print('Scan iplist/16')
            for ip in iplist:
                BscanPortBanner(ip + '/16', ports)
        elif ipfile == 'ip8.txt':
            #print('Scan iplist/8')
            for ip in iplist:
                AscanPortBanner(ip + '/8', ports)
        else:
            #print('Scan iplist (any txt file)')
            for ip in iplist:
                CscanPortBanner(ip, ports)
    elif ip != None:
        if '/16' in ip:
            BscanPortBanner(ip, ports)
        elif '/8' in ip:
            AscanPortBanner(ip, ports)
        elif '/24' in ip:
            CscanPortBanner(ip, ports)
        else:
            CscanPortBanner(ip, ports)
