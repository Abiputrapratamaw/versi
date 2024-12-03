#!/bin/bash

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default settings
DISK="/dev/vda"
MOUNT_POINT="/mnt/windows"
WIN_REG_SYSTEM="/mnt/windows/Windows/System32/config/SYSTEM"
WIN_REG_SAM="/mnt/windows/Windows/System32/config/SAM"
TEMP_DIR="/tmp/windows_install"
IMAGE_URL="$1"

# Function untuk cek dan install dependencies
check_dependencies() {
    echo -e "${YELLOW}Installing required packages...${NC}"
    apt-get update
    apt-get install -y wget pv chntpw ipcalc curl ntfs-3g
}

# Function untuk download image
download_windows() {
    echo -e "${YELLOW}Downloading Windows image from: $IMAGE_URL${NC}"
    mkdir -p $TEMP_DIR
    wget --progress=bar:force --no-check-certificate "$IMAGE_URL" -O $TEMP_DIR/windows.gz
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Download completed${NC}"
}

# Get Administrator password
get_password() {
    echo -e "${YELLOW}Set Administrator password:${NC}"
    while true; do
        read -s -p "New password: " NEW_PASS
        echo
        read -s -p "Confirm password: " NEW_PASS2
        echo
        
        if [ "$NEW_PASS" = "$NEW_PASS2" ]; then
            if [ ${#NEW_PASS} -lt 8 ]; then
                echo -e "${RED}Password must be at least 8 characters long${NC}"
            else
                break
            fi
        else
            echo -e "${RED}Passwords do not match${NC}"
        fi
    done
}

# Write image to disk
write_image() {
    echo -e "${YELLOW}Writing image to disk...${NC}"
    gunzip -c $TEMP_DIR/windows.gz | pv -pterb | dd of="$DISK" bs=4M conv=noerror,sync
    sync
}

# Reset Administrator password
reset_password() {
    echo -e "${YELLOW}Resetting Administrator password...${NC}"
    
    # Reset Administrator password in SAM
    cat > /tmp/reset_admin.txt << EOF
cd ..
cd SAM
cd Domains\\Account\\Users\\000001F4
ed F
*BLANK*
EOF
    chntpw -e $WIN_REG_SAM < /tmp/reset_admin.txt

    # Create script to set new password on first boot
    cat > $MOUNT_POINT/Windows/reset_pass.bat << EOF
@echo off
net user Administrator "${NEW_PASS}"
del %~f0
EOF
    
    mkdir -p "$MOUNT_POINT/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp/"
    cp $MOUNT_POINT/Windows/reset_pass.bat "$MOUNT_POINT/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp/"
}

# Configure network
configure_network() {
    echo -e "${YELLOW}Configuring network settings...${NC}"
    IP=$(curl -4 -s icanhazip.com)
    NETMASK=$(255.255.240.0.)
    GATEWAY=$(ip route | awk '/default/ { print $3 }')
    MAC=$(82:4d:fe:b9:5a:f0)
    
    # Set network in registry
    cat > /tmp/network.reg << EOF
cd ControlSet001\\Services\\Tcpip\\Parameters\\Interfaces\\{$MAC}
nk {$MAC}
cd {$MAC}
ed IPAddress
$IP
ed SubnetMask
$NETMASK
ed DefaultGateway
$GATEWAY
ed EnableDHCP
0
EOF

    chntpw -e $WIN_REG_SYSTEM < /tmp/network.reg
    
    # Create network setup script
    cat > $MOUNT_POINT/Windows/setup_network.bat << EOF
@echo off
netsh interface ip set address name="Ethernet" static $IP $NETMASK $GATEWAY
netsh interface ip set dns name="Ethernet" static 8.8.8.8
netsh interface ip add dns name="Ethernet" 8.8.4.4 index=2
del %~f0
EOF
    
    cp $MOUNT_POINT/Windows/setup_network.bat "$MOUNT_POINT/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp/"
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -rf $TEMP_DIR
    rm -f /tmp/reset_admin.txt /tmp/network.reg
    umount $MOUNT_POINT 2>/dev/null || true
}

# Main script
clear
echo "=== Windows HTTPS Image Installation ==="

# Check if URL provided
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <https-url-to-windows.gz>${NC}"
    echo "Example: $0 https://storage.example.com/windows-server.gz"
    exit 1
fi

# Verify URL format
if [[ "$IMAGE_URL" != https://* ]]; then
    echo -e "${RED}URL must start with https://${NC}"
    exit 1
fi

# Install dependencies
check_dependencies

# Get password before starting
get_password

# Confirm installation
echo -e "${RED}WARNING: All data on $DISK will be erased!${NC}"
read -p "Continue? (y/N): " confirm
if [ "$confirm" != "y" ]; then
    echo "Operation cancelled"
    exit 1
fi

# Download and install
echo -e "${YELLOW}Starting installation process...${NC}"
download_windows
write_image

# Mount Windows partition
echo -e "${YELLOW}Mounting Windows partition...${NC}"
mkdir -p $MOUNT_POINT
mount ${DISK}1 $MOUNT_POINT || { echo -e "${RED}Failed to mount Windows partition${NC}"; exit 1; }

# Configure Windows
reset_password
configure_network

# Final cleanup
cleanup

echo -e "${GREEN}Installation completed!${NC}"
echo "System will reboot in 10 seconds..."
echo "After reboot:"
echo "- Windows will start automatically"
echo "- Network will be configured"
echo "- Use the new password to login as Administrator"
sleep 10
reboot
