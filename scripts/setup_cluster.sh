#!/bin/bash

# Disable swap immediately
echo "Disabling swap..."
sudo swapoff -a

# Disable swap in /etc/fstab to persist across reboots
echo "Disabling swap in /etc/fstab..."
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Swap disabled successfully."
