#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Get network info
MAIN_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
PRIVATE_IP=$(ip -4 addr show $MAIN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
NETMASK=$(ip -f inet addr show $MAIN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | cut -d'/' -f2 | head -n1)

# Backup current config
cp /etc/network/interfaces /etc/network/interfaces.backup

# Create new network config
cat > /etc/network/interfaces <<EOL
auto lo
iface lo inet loopback

auto $MAIN_INTERFACE
iface $MAIN_INTERFACE inet manual

auto vmbr0
iface vmbr0 inet static
        address $PRIVATE_IP
        netmask $NETMASK
        gateway $GATEWAY
        bridge-ports $MAIN_INTERFACE
        bridge-stp off
        bridge-fd 0
EOL

# Restart networking
echo "Restarting networking..."
systemctl restart networking

# Verify bridge creation
echo "Checking bridge status..."
ip a show vmbr0

echo "Network configuration has been updated!"
echo "New network config:"
cat /etc/network/interfaces
echo ""
echo "Please verify network connectivity and bridge status."
echo "Original config backed up to: /etc/network/interfaces.backup"
