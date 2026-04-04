#!/bin/bash
# Activity 2 - BIND9 Setup Script (Internal Gateway)
# Downloads config files from GitHub and places them correctly
# Students: after running this, nano each file and replace YOURDOMAIN

set -e

REPO="https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity2/bind"

echo "[1/6] Installing BIND9..."
sudo apt update -q
sudo apt install bind9 bind9utils bind9-doc -y -q

echo "[2/6] Downloading named.conf.options (no changes needed)..."
sudo curl -fsSL "$REPO/named.conf.options" -o /etc/bind/named.conf.options

echo "[3/6] Downloading named.conf.local..."
sudo curl -fsSL "$REPO/named.conf.local" -o /etc/bind/named.conf.local

echo "[4/6] Creating zones directory..."
sudo mkdir -p /etc/bind/zones

echo "[5/6] Downloading zone files..."
sudo curl -fsSL "$REPO/db.YOURDOMAIN.com" -o /etc/bind/zones/db.YOURDOMAIN.com
sudo curl -fsSL "$REPO/db.192.168.1"     -o /etc/bind/zones/db.192.168.1

echo "[6/6] Enabling named service..."
sudo systemctl enable named

echo ""
echo "========================================="
echo " Download complete. Now do the following:"
echo "========================================="
echo ""
echo " 1. Edit named.conf.local — replace YOURDOMAIN with your domain:"
echo "    sudo nano /etc/bind/named.conf.local"
echo ""
echo " 2. Rename and edit the forward zone file:"
echo "    sudo mv /etc/bind/zones/db.YOURDOMAIN.com /etc/bind/zones/db.yourname-coursecode.com"
echo "    sudo nano /etc/bind/zones/db.yourname-coursecode.com"
echo "    (replace all instances of YOURDOMAIN with your domain)"
echo ""
echo " 3. Edit the reverse zone file:"
echo "    sudo nano /etc/bind/zones/db.192.168.1"
echo "    (replace all instances of YOURDOMAIN with your domain)"
echo ""
echo " 4. When done editing, check config then restart:"
echo "    sudo named-checkconf"
echo "    sudo named-checkzone yourname-coursecode.com /etc/bind/zones/db.yourname-coursecode.com"
echo "    sudo systemctl restart named"
echo "========================================="
