#!/bin/bash

# Auto Windows Network Installer
# Hanya perlu Windows Image URL

export DEBIAN_FRONTEND=noninteractive

# Parse arguments
POSITIONAL=()
while [[ $# -ge 1 ]]; do
  case $1 in
    -d|--debug)
      shift
      isDebug="yes"
      ;;
    -y|--yes)
      shift
      confirm="yes"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

export DDURL=$1    # Windows Image URL satu-satunya parameter yang diperlukan

# Root check
if [ "$(id -u)" != "0" ]; then
  echo "Error: Script harus dijalankan sebagai root!"
  exit 1
fi

# Fungsi untuk membuat custom initramfs
create_custom_initramfs() {
    # Buat direktori kerja
    work_dir="/tmp/custom_initramfs"
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    cd "$work_dir"

    # Extract base initramfs
    mkdir -p initramfs
    cd initramfs
    gunzip -c /boot/initrd.img-$(uname -r) | cpio -id

    # Buat init script dengan auto detection
    cat > init << 'EOF'
#!/bin/sh

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Auto detect network interface
for iface in $(ls /sys/class/net/); do
    if [ "$iface" != "lo" ] && [ ! -d "/sys/class/net/$iface/wireless" ] && [ ! -d "/sys/class/net/$iface/bridge" ] && [ ! -d "/sys/class/net/$iface/bonding" ]; then
        interface=$iface
        break
    fi
done

# Tunggu interface siap
sleep 5

# Setup DHCP untuk dapatkan IP otomatis
udhcpc -i $interface -s /usr/share/udhcpc/default.script

# Setup DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Auto detect disk
disk=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}' | head -n1)

# Download Windows image
echo "Downloading Windows image..."
wget -O /windows.img "$1"
if [ $? -ne 0 ]; then
    echo "Failed to download Windows image!"
    sleep 5
    reboot -f
fi

# Write image ke disk
echo "Writing image to $disk..."
dd if=/windows.img of=$disk bs=4M status=progress

# Sync dan reboot
sync
echo b > /proc/sysrq-trigger
EOF

    chmod +x init

    # Copy tools yang diperlukan
    cp /bin/busybox .
    cp /usr/bin/wget .
    cp /bin/dd .
    mkdir -p usr/share/udhcpc
    cp /usr/share/udhcpc/default.script usr/share/udhcpc/
    
    # Setup busybox symlinks
    ./busybox --install .

    # Copy library dependencies
    for bin in busybox wget dd; do
        for lib in $(ldd $(which $bin) 2>/dev/null | grep -o '/lib.*\.[0-9]'); do
            mkdir -p .$lib
            cp $lib .$lib/
        done
    done

    # Buat initramfs baru
    find . | cpio -H newc -o | gzip > ../custom_initramfs.gz
    cd ..
    mv custom_initramfs.gz /boot/
}

# Setup GRUB
setup_grub() {
    GRUBDIR=/boot/grub
    GRUBFILE=grub.cfg
    
    # Buat GRUB entry baru
    cat > /tmp/grub.new << EOF
menuentry "Windows Network Installer" {
    linux /boot/vmlinuz-$(uname -r) quiet
    initrd /boot/custom_initramfs.gz
    set DDURL="$DDURL"
}
EOF

    # Backup GRUB config asli
    cp $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.backup

    # Tambahkan entry baru
    sed -i '/menuentry/i\$(cat /tmp/grub.new)\n' $GRUBDIR/$GRUBFILE

    # Set default boot ke installer
    grub-set-default "Windows Network Installer"
    update-grub
}

# Main installation process
main() {
    clear
    echo "Starting Windows Network Installer Setup..."

    # Validasi Windows image URL
    if [ -z "$DDURL" ]; then
        echo "Error: Windows image URL required!"
        echo "Usage: $0 [Windows_Image_URL]"
        exit 1
    fi

    # Auto detect disk
    disk=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}' | head -n1)
    
    # Auto detect network info
    interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    ip_info=$(ip addr show dev $interface | grep 'inet ' | head -n1)
    ip_addr=$(echo $ip_info | awk '{print $2}' | cut -d/ -f1)

    # Konfirmasi
    if [ "$confirm" != "yes" ]; then
        echo -e "\nDetected Configuration:"
        echo "Windows Image: $DDURL"
        echo "Target Disk: $disk"
        echo "Network Interface: $interface"
        echo "Current IP: $ip_addr"
        
        read -p "Continue setup? (y/n): " answer
        [ "$answer" != "y" ] && exit 0
    fi

    # Install dependencies
    apt-get update
    apt-get install -y wget busybox cpio gzip grub2 udhcpc

    # Create custom initramfs
    create_custom_initramfs

    # Setup GRUB
    setup_grub

    echo "Setup completed! System will reboot to start Windows installation."
    
    if [ "$isDebug" != "yes" ]; then
        sleep 3
        reboot
    fi
}

# Start setup
main "$@"
