#!/bin/bash
# Activity 2 - BIND9 Setup Script (Internal Gateway)
# Downloads config files from GitHub and places them correctly
# After running this, follow the instructions printed at the end

set -e

REPO="https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity2/bind"

echo "[1/7] Installing BIND9..."
sudo apt update -q
sudo apt install bind9 bind9utils bind9-doc -y -q

echo "[2/7] Downloading named.conf.options (no changes needed)..."
sudo curl -fsSL "$REPO/named.conf.options" -o /etc/bind/named.conf.options

echo "[3/7] Downloading named.conf.local..."
sudo curl -fsSL "$REPO/named.conf.local" -o /etc/bind/named.conf.local

echo "[4/7] Creating zones directory..."
sudo mkdir -p /etc/bind/zones

echo "[5/7] Downloading zone files..."
sudo curl -fsSL "$REPO/db.YOURDOMAIN.com" -o /etc/bind/zones/db.YOURDOMAIN.com
sudo curl -fsSL "$REPO/db.192.168.1"      -o /etc/bind/zones/db.192.168.1

echo "[6/7] Adding TCP-only server blocks to named.conf (Azure blocks outbound UDP 53)..."
sudo curl -fsSL "$REPO/named.conf.append" | sudo tee -a /etc/bind/named.conf > /dev/null

echo "[7/7] Enabling named service..."
sudo systemctl enable named

echo ""
echo "============================================================"
echo " Download complete. Now do the following steps in order:"
echo "============================================================"
echo ""
echo " STEP 1 — Edit named.conf.local (replace YOURDOMAIN twice):"
echo "   sudo nano /etc/bind/named.conf.local"
echo ""
echo " STEP 2 — Rename the forward zone file to your domain:"
echo "   sudo mv /etc/bind/zones/db.YOURDOMAIN.com \\"
echo "           /etc/bind/zones/db.yourname-coursecode.com"
echo ""
echo " STEP 3 — Edit the forward zone file (replace YOURDOMAIN throughout):"
echo "   sudo nano /etc/bind/zones/db.yourname-coursecode.com"
echo ""
echo " STEP 4 — Edit the reverse zone file (replace YOURDOMAIN throughout):"
echo "   sudo nano /etc/bind/zones/db.192.168.1"
echo ""
echo " STEP 5 — Validate config and zone files:"
echo "   sudo named-checkconf"
echo "   sudo named-checkzone yourname-coursecode.com \\"
echo "        /etc/bind/zones/db.yourname-coursecode.com"
echo "   sudo named-checkzone 1.168.192.in-addr.arpa \\"
echo "        /etc/bind/zones/db.192.168.1"
echo ""
echo " STEP 6 — Restart named:"
echo "   sudo systemctl restart named"
echo "============================================================"
