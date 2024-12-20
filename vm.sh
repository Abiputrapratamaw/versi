#!/bin/bash

# Fungsi untuk membuat nama random
generate_random_name() {
  echo "UbuntuAutoRoot-$RANDOM"
}

# Cari VM ID yang kosong
find_empty_vm_id() {
  for i in {100..999}; do
    if ! qm list | grep -q "^$i "; then
      echo "$i"
      return
    fi
  done
}

# Pilih ISO yang tersedia
select_iso() {
  echo "ISO yang tersedia di direktori /var/lib/vz/template/iso/:"
  ls /var/lib/vz/template/iso/*.iso || { echo "Tidak ada file ISO yang ditemukan!"; exit 1; }
  echo
  read -p "Masukkan nama ISO yang akan digunakan (contoh: ubuntu-22.04-live-server-amd64.iso): " iso_name
  iso_path="/var/lib/vz/template/iso/$iso_name"
  
  # Periksa apakah file ISO ada
  if [[ -f $iso_path ]]; then
    echo "$iso_path"
  else
    echo "File ISO tidak ditemukan: $iso_path"
    exit 1
  fi
}

# Input pengguna
read -p "Masukkan ukuran disk (contoh: 20G): " disk_size
read -p "Masukkan RAM (dalam MB, contoh: 2048): " ram_size
read -p "Masukkan jumlah CPU cores (contoh: 2): " cpu_cores
read -p "Masukkan password root untuk Cloud-Init: " root_password

# Variabel otomatis
VM_ID=$(find_empty_vm_id)
VM_NAME=$(generate_random_name)
STORAGE="local"
ISO_PATH=$(select_iso)
BRIDGE="vmbr0"

# Buat VM
echo "Membuat VM dengan ID $VM_ID dan nama $VM_NAME..."
qm create "$VM_ID" --name "$VM_NAME" --memory "$ram_size" --cores "$cpu_cores" --net0 virtio,bridge=$BRIDGE

# Tambahkan disk ke VM
echo "Menambahkan disk ke VM..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$STORAGE:$disk_size"

# Tambahkan CD-ROM dengan ISO Ubuntu
echo "Menambahkan ISO Ubuntu sebagai CD-ROM..."
qm set "$VM_ID" --ide2 "$STORAGE:iso/$(basename $ISO_PATH)" --boot c --bootdisk scsi0

# Aktifkan Cloud-Init dengan password root
echo "Mengaktifkan Cloud-Init untuk konfigurasi otomatis..."
qm set "$VM_ID" --ciuser root --cipassword "$root_password" --ipconfig0 ip=dhcp --searchdomain local --nameserver 8.8.8.8

# Selesaikan konfigurasi
echo "Konfigurasi selesai. Memulai VM..."
qm start "$VM_ID"

# Informasi akhir
echo "VM $VM_NAME telah dibuat dengan ID $VM_ID."
echo "Root password: $root_password"
