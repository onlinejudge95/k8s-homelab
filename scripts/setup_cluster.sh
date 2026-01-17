#!/bin/bash

set -e

# Ensure the script is run with appropriate privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo or as root."
    exit 1
fi
# Disable swap immediately
echo "Disabling swap..."
sudo swapoff -a

# Disable swap in /etc/fstab to persist across reboots
echo "Disabling swap in /etc/fstab..."
sudo sed -i.bak '/[[:space:]]swap[[:space:]]/ s/^\(.*\)$/#\1/g' /etc/fstab

echo "Swap disabled successfully."
