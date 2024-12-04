#!/bin/bash

# Windows Network Auto Configuration Installer
# Support untuk Windows Image Custom .gz

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

export DDURL=$1    # Windows Image URL

# Root check
if [ "$(id -u)" != "0" ]; then
  echo "Error: Script harus dijalankan sebagai root!"
  exit 1
fi

# Fungsi untuk membuat custom initramfs
create_custom_initramfs() {
    work_dir="/tmp/custom_initramfs"
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    cd "$work_dir"

    mkdir -p initramfs
    cd initramfs
    gunzip -c /boot/initrd.img-$(uname -r) | cpio -id

    # Buat init script dengan sistem minimal dan auto config
    cat > init << 'EOF'
#!/bin/sh

# Kill semua proses yang berjalan
for pid in $(ps aux | grep -v "^\[" | awk '{print $1}'); do
    kill -9 $pid 2>/dev/null
done

# Unmount semua filesystem
for mnt in $(mount | grep -v "^/dev" | awk '{print $3}' | sort -r); do
    umount -l $mnt 2>/dev/null
done

# Mount filesystem essential
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Disable semua network interface dulu
for iface in $(ls /sys/class/net/); do
    if [ "$iface" != "lo" ]; then
        ip link set $iface down
    fi
done

# Auto detect dan setup network interface
for iface in $(ls /sys/class/net/); do
    if [ "$iface" != "lo" ] && [ ! -d "/sys/class/net/$iface/wireless" ] && \
       [ ! -d "/sys/class/net/$iface/bridge" ] && [ ! -d "/sys/class/net/$iface/bonding" ]; then
        interface=$iface
        ip link set $interface up
        sleep 2
        break
    fi
done

# Setup DHCP
udhcpc -i $interface -s /usr/share/udhcpc/default.script

# Setup DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Auto detect disk
disk=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}' | head -n1)

echo "Starting Windows Installation..."
echo "Target disk: $disk"

# Matikan semua swap
swapoff -a

# Unmount semua partisi pada target disk
for part in $(lsblk -n -o NAME $disk | tail -n +2); do
    umount -f /dev/$part 2>/dev/null
done

# Ambil network info untuk Windows
ip_addr=$(ip addr show dev $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
netmask=$(ip addr show dev $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f2)
gateway=$(ip route | grep default | awk '{print $3}')

# Buat direktori mount sementara
mkdir -p /windows_mount

# Download dan extract Windows image
echo "Downloading Windows image..."
if echo "$1" | grep -q "\.gz$"; then
    # Download dan extract
    wget -O- "$1" | gunzip -c > /windows.img
else
    # Download langsung
    wget -O /windows.img "$1"
fi

if [ $? -ne 0 ]; then
    echo "Download failed!"
    sleep 5
    reboot -f
fi

# Write image ke disk
echo "Writing image to disk..."
dd if=/windows.img of=$disk bs=4M status=progress

if [ $? -ne 0 ]; then
    echo "Write failed!"
    sleep 5
    reboot -f
fi

# Tunggu disk siap
sync
sleep 5

# Mount partisi Windows (biasanya partisi kedua untuk Windows)
mount ${disk}2 /windows_mount || mount ${disk}1 /windows_mount

# Konfigurasi network Windows
if [ -d "/windows_mount/Windows" ]; then
    # Buat file konfigurasi network
    cat > /windows_mount/Windows/System32/config_net.bat << NETEOF
@echo off
netsh interface ip set address name="Ethernet" source=static addr=$ip_addr mask=$netmask gateway=$gateway
netsh interface ip add dns name="Ethernet" addr=8.8.8.8 index=1
netsh interface ip add dns name="Ethernet" addr=8.8.4.4 index=2
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
NETEOF

    # Tambahkan ke startup
    mkdir -p "/windows_mount/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp"
    cp /windows_mount/Windows/System32/config_net.bat "/windows_mount/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp/"
fi

# Unmount dan sync
umount /windows_mount
sync

echo "Installation and configuration complete! Rebooting..."
sleep 3

# Force reboot
echo b > /proc/sysrq-trigger
EOF

    chmod +x init

    # Copy tools yang diperlukan
    cp /bin/busybox .
    cp /usr/bin/wget .
    cp /bin/dd .
    cp /bin/gunzip .
    mkdir -p usr/share/udhcpc
    cp /usr/share/udhcpc/default.script usr/share/udhcpc/
    
    # Setup busybox symlinks
    ./busybox --install .

    # Copy library dependencies
    for bin in busybox wget dd gunzip; do
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

# Setup GRUB untuk pure initramfs boot
setup_grub() {
    GRUBDIR=/boot/grub
    GRUBFILE=grub.cfg
    
    # Buat GRUB entry baru
    cat > /tmp/grub.new << EOF
menuentry "Windows Network Installer" {
    linux /boot/vmlinuz-$(uname -r) init=/init root=/dev/ram0 rw quiet loglevel=0 systemd.unit=emergency.target
    initrd /boot/custom_initramfs.gz
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
    echo "WARNING: System will be inaccessible during installation!"
    echo "After installation, Windows will automatically configure network settings."
    
    if [ "$isDebug" != "yes" ]; then
        sleep 3
        reboot
    fi
}

# Start setup
main "$@"
