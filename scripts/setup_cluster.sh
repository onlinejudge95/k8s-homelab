#!/bin/bash

set -e

# Ensure the script is run with appropriate privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo or as root."
    exit 1
fi

# Disable swap immediately
echo "Disabling swap..."
swapoff -a

# Disable swap in /etc/fstab to persist across reboots
echo "Disabling swap in /etc/fstab..."
sed -i.bak '/[[:space:]]swap[[:space:]]/ s/^\(.*\)$/#\1/g' /etc/fstab

echo "Swap disabled successfully."

# Load kernel modules
echo "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

if ! modprobe overlay; then
    echo "Error: Failed to load overlay kernel module."
    exit 1
fi

if ! modprobe br_netfilter; then
    echo "Error: Failed to load br_netfilter kernel module."
    exit 1
fi

# Set system configurations for Kubernetes networking
echo "Setting system configurations..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "Kernel modules loaded and system configurations applied."

# Installing containerd
echo "Installing containerd..."

apt-get update
apt-get install --assume-yes ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install --assume-yes containerd.io