#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Prompt for hostname
read -p "Enter hostname for Proxmox server (default: pve): " HOSTNAME
HOSTNAME=${HOSTNAME:-pve}

# Function to get IP addresses
get_ips() {
    # Get primary interface
    MAIN_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
    
    # Get Private IPv4
    PRIVATE_IP=$(ip -4 addr show $MAIN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    
    # Get Public IPv4 (multiple methods)
    PUBLIC_IP=$(curl -4 -s ifconfig.me || curl -4 -s icanhazip.com || curl -4 -s ipinfo.io/ip)
    
    # Get gateway and netmask
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
    NETMASK=$(ip -f inet addr show $MAIN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | cut -d'/' -f2 | head -n1)
}

# Get IP configurations
get_ips

# Verify IPs were obtained
if [ -z "$PRIVATE_IP" ] || [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not obtain IP addresses. Please check network connection."
    exit 1
fi

# Backup original files
cp /etc/apt/sources.list /etc/apt/sources.list.backup
cp /etc/hosts /etc/hosts.backup

# Update system and install prerequisites
echo "Updating system and installing prerequisites..."
apt update && apt upgrade -y
apt install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates curl

# Add Proxmox VE repository
echo "Adding Proxmox VE repository..."
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Remove subscription notice
echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/usr/share/javascript/proxmox-widget-toolkit/tk/data/update-status.js' && sed -i 's/getNoSubscriptionDialogStatus() {/getNoSubscriptionDialogStatus() { return false;/g' /usr/share/javascript/proxmox-widget-toolkit/tk/data/update-status.js || true\"; };" > /etc/apt/apt.conf.d/99-proxmox-updates

# Update repository and install Proxmox VE
echo "Installing Proxmox VE..."
apt update
apt full-upgrade -y
apt install -y proxmox-ve postfix open-iscsi

# Configure network
echo "Configuring network..."

cat > /etc/network/interfaces <<EOL
auto lo
iface lo inet loopback

auto vmbr0
iface vmbr0 inet static
        address $PRIVATE_IP
        netmask $NETMASK
        gateway $GATEWAY
        bridge-ports $MAIN_INTERFACE
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
EOL

# Remove enterprise repository
rm /etc/apt/sources.list.d/pve-enterprise.list*

# Configure hostname
echo $HOSTNAME > /etc/hostname
hostnamectl set-hostname $HOSTNAME

# Configure hosts file
cat > /etc/hosts <<EOL
127.0.0.1 localhost

# Private IP (for internal communication)
$PRIVATE_IP $HOSTNAME

# Public IP (for external access)
$PUBLIC_IP $HOSTNAME

# IPv6 defaults
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOL

# Enable BBR congestion control and network optimizations
cat >> /etc/sysctl.conf <<EOL
# Network performance tuning
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.core.netdev_max_backlog=65535

# TCP optimizations
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
EOL

# Apply sysctl changes
sysctl -p

echo "Installation completed!"
echo "Configuration details:"
echo "Private IP: $PRIVATE_IP (for internal/VM network)"
echo "Public IP: $PUBLIC_IP (for external access)"
echo "Hostname: $HOSTNAME"
echo "Main Interface: $MAIN_INTERFACE"
echo ""
echo "Network configuration:"
cat /etc/network/interfaces
echo ""
echo "Hosts configuration:"
cat /etc/hosts
echo ""
echo "Please reboot your system to complete the setup."
echo "After reboot, you can access Proxmox web interface using either:"
echo "Private IP (internal): https://$PRIVATE_IP:8006"
echo "Public IP (external): https://$PUBLIC_IP:8006"
echo ""
echo "Default credentials:"
echo "Username: root"
echo "Password: [your root password]"
echo ""
echo "TIPS:"
echo "1. Use Private IP for VM networks and internal communication"
echo "2. Use Public IP for accessing web interface from internet"
echo "3. Consider setting up fail2ban for additional security"

# Prompt for reboot
read -p "Would you like to reboot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    reboot
fi
