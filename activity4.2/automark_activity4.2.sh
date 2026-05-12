#!/bin/bash
# =============================================================================
# Automarking Script - Activity 4-2: VPN with OpenVPN
# 7015ICT | Griffith University
# =============================================================================
# Run on any VM — the script auto-detects which VM it is on and runs the
# appropriate checks. For a full picture, run it on every VM.
#
# Error code reference (see Activity 4-2 guide Troubleshooting section):
#   E1  — OpenVPN not installed
#   E2  — Easy-RSA not installed or working directory missing
#   E3  — PKI not initialised (pki/ directory missing)
#   E4  — CA certificate missing
#   E5  — Server certificate or key missing
#   E6  — DH parameters missing
#   E7  — TLS auth key missing
#   E8  — Required certificates not copied to /etc/openvpn
#   E9  — OpenVPN server config missing or incomplete
#   E10 — IP forwarding not enabled
#   E11 — OpenVPN service not running or not enabled
#   E12 — tun0 interface missing or wrong IP on Internal Gateway
#   E13 — Client certificate or key missing
#   E14 — client1.ovpn bundle not generated
#   E15 — base.conf remote IP not set (still contains placeholder)
#   E16 — UDP 1194 forward rule missing from External Gateway nftables
#   E17 — UDP 1194 DNAT rule missing from External Gateway nftables
#   E18 — UDP 1194 SNAT rule missing from External Gateway nftables
#   E19 — nftables config not saved / rules not persistent
#   E20 — client1.ovpn not present on OpenVPN Client VM
#   E21 — OpenVPN or NM plugin not installed on Client VM
#   E22 — tun0 missing or wrong IP on Client VM (VPN not connected)
#   E23 — Ping from Client VM to Internal Gateway tun0 fails
#   E24 — Client VM cannot reach DMZ (192.168.1.80) via VPN
#
# Usage: sudo bash automark_activity4.2.sh
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "  [ERROR] Please run with sudo: sudo bash automark_activity4.2.sh"
    echo ""
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
ERRORS=()

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}[FAIL]${NC} $2"; echo -e "         ${YELLOW}→ Error $1${NC}"; ERRORS+=("$1"); ((FAIL++)) || true; }
info() { echo -e "  ${CYAN}[INFO]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
section() { echo ""; echo -e "${BOLD}--- $1 ---${NC}"; }

has_ip() { ip addr show 2>/dev/null | grep -q "inet $1"; }

# =============================================================================
# Detect VM
# =============================================================================
detect_vm() {
    if has_ip "192.168.1.254"; then
        echo "external_gateway"
    elif has_ip "192.168.1.1" && has_ip "10.10.1.254"; then
        echo "internal_gateway"
    elif has_ip "192.168.1.80"; then
        echo "ubuntu_server"
    elif has_ip "10.10.1.1"; then
        echo "ubuntu_desktop"
    else
        # Could be the OpenVPN Client VM (DHCP on external network, no fixed IP)
        # Identify by checking if openvpn is installed and no other IPs match
        if command -v openvpn &>/dev/null; then
            echo "openvpn_client"
        else
            echo "unknown"
        fi
    fi
}

# =============================================================================
# Internal Gateway — OpenVPN server, PKI, certificates
# =============================================================================
run_internal_gateway() {
    echo -e "\n${BOLD}${CYAN}VM detected: Internal Gateway${NC}"

    # =========================================================================
    section "OpenVPN and Easy-RSA Installation"
    # =========================================================================
    if command -v openvpn &>/dev/null; then
        pass "OpenVPN installed ($(openvpn --version 2>&1 | head -1))"
    else
        fail "E1" "OpenVPN is not installed — run: sudo apt install openvpn -y"
    fi

    if [ -f ~/openvpn-ca/easyrsa ]; then
        pass "Easy-RSA working directory exists (~/openvpn-ca/easyrsa)"
    else
        fail "E2" "Easy-RSA not found at ~/openvpn-ca/easyrsa — check setup"
        info "Run: sudo mkdir ~/openvpn-ca && sudo ln -s /usr/share/easy-rsa/* ~/openvpn-ca/"
    fi

    if [ -f ~/openvpn-ca/vars ]; then
        pass "vars file present (~/openvpn-ca/vars)"
    else
        fail "E2" "vars file missing at ~/openvpn-ca/vars"
        info "Create vars file with EASYRSA_REQ_* variables"
    fi

    # =========================================================================
    section "PKI and Certificates"
    # =========================================================================
    if [ -d ~/openvpn-ca/pki ]; then
        pass "PKI directory initialised (~/openvpn-ca/pki)"
    else
        fail "E3" "PKI not initialised — run: cd ~/openvpn-ca && ./easyrsa init-pki"
    fi

    if [ -f ~/openvpn-ca/pki/ca.crt ]; then
        pass "CA certificate present (pki/ca.crt)"
    else
        fail "E4" "CA certificate missing — run: cd ~/openvpn-ca && ./easyrsa build-ca"
    fi

    if [ -f ~/openvpn-ca/pki/issued/server.crt ]; then
        pass "Server certificate present (pki/issued/server.crt)"
    else
        fail "E5" "Server certificate missing — run: ./easyrsa sign-req server server"
    fi

    if [ -f ~/openvpn-ca/pki/private/server.key ]; then
        pass "Server key present (pki/private/server.key)"
    else
        fail "E5" "Server key missing — run: ./easyrsa gen-req server nopass"
    fi

    if [ -f ~/openvpn-ca/pki/dh.pem ]; then
        pass "DH parameters present (pki/dh.pem)"
    else
        fail "E6" "DH parameters missing — run: ./easyrsa gen-dh"
    fi

    if [ -f ~/openvpn-ca/ta.key ]; then
        pass "TLS auth key present (~/openvpn-ca/ta.key)"
    else
        fail "E7" "TLS auth key missing — run: openvpn --genkey --secret ~/openvpn-ca/ta.key"
    fi

    # =========================================================================
    section "Certificates Copied to /etc/openvpn"
    # =========================================================================
    for f in ca.crt server.crt server.key dh2048.pem ta.key; do
        if [ -f /etc/openvpn/$f ]; then
            pass "$f present in /etc/openvpn/"
        else
            fail "E8" "$f missing from /etc/openvpn/ — copy from ~/openvpn-ca/pki/"
        fi
    done

    # =========================================================================
    section "OpenVPN Server Configuration"
    # =========================================================================
    if [ -f /etc/openvpn/server.conf ]; then
        pass "/etc/openvpn/server.conf exists"
        local conf
        conf=$(cat /etc/openvpn/server.conf 2>/dev/null)

        for directive in "port 1194" "proto udp" "dev tun" "server 10.8.0.0" "tls-auth ta.key"; do
            if echo "$conf" | grep -q "$directive"; then
                pass "server.conf: '$directive' found"
            else
                fail "E9" "server.conf: '$directive' missing"
            fi
        done

        if echo "$conf" | grep -q 'push "route 192.168.1.0'; then
            pass "server.conf: push route to 192.168.1.0/24 present"
        else
            fail "E9" "server.conf: push route for 192.168.1.0/24 missing"
            info 'Add: push "route 192.168.1.0 255.255.255.0"'
        fi
    else
        fail "E9" "/etc/openvpn/server.conf not found"
        info "Create server.conf from the Activity 4-2 guide"
    fi

    # =========================================================================
    section "IP Forwarding"
    # =========================================================================
    local ip_fwd
    ip_fwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    if [ "$ip_fwd" = "1" ]; then
        pass "IP forwarding is enabled (/proc/sys/net/ipv4/ip_forward = 1)"
    else
        fail "E10" "IP forwarding is disabled — run: echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward"
        info "Make persistent: add 'net.ipv4.ip_forward = 1' to /etc/sysctl.conf"
    fi

    if grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf 2>/dev/null; then
        pass "IP forwarding is persistent in /etc/sysctl.conf"
    else
        fail "E10" "IP forwarding not set in /etc/sysctl.conf — will reset after reboot"
        info "Add: net.ipv4.ip_forward = 1 to /etc/sysctl.conf"
    fi

    # =========================================================================
    section "OpenVPN Service"
    # =========================================================================
    if systemctl is-active --quiet openvpn@server 2>/dev/null; then
        pass "OpenVPN server service is active (openvpn@server)"
    else
        fail "E11" "OpenVPN server is not running — run: sudo systemctl start openvpn@server"
        info "Check logs: sudo journalctl -u openvpn@server --no-pager | tail -20"
    fi

    if systemctl is-enabled --quiet openvpn@server 2>/dev/null; then
        pass "OpenVPN server service is enabled (starts on boot)"
    else
        fail "E11" "OpenVPN server not enabled — run: sudo systemctl enable openvpn@server"
    fi

    # =========================================================================
    section "tun0 Interface"
    # =========================================================================
    if ip addr show tun0 &>/dev/null; then
        local tun_ip
        tun_ip=$(ip addr show tun0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ "$tun_ip" = "10.8.0.1" ]; then
            pass "tun0 interface present with correct IP (10.8.0.1)"
        else
            fail "E12" "tun0 exists but IP is $tun_ip — expected 10.8.0.1"
            info "Check server.conf: 'server 10.8.0.0 255.255.255.0'"
        fi
    else
        fail "E12" "tun0 interface not present — OpenVPN server may not be running correctly"
        info "Check: sudo systemctl status openvpn@server"
    fi

    # =========================================================================
    section "Client Certificate and Configuration"
    # =========================================================================
    if [ -f ~/openvpn-ca/pki/issued/client1.crt ]; then
        pass "Client certificate present (pki/issued/client1.crt)"
    else
        fail "E13" "Client certificate missing — run: cd ~/openvpn-ca && ./easyrsa sign-req client client1"
    fi

    if [ -f ~/openvpn-ca/pki/private/client1.key ]; then
        pass "Client key present (pki/private/client1.key)"
    else
        fail "E13" "Client key missing — run: ./easyrsa gen-req client1 nopass"
    fi

    if [ -f ~/client-configs/files/client1.ovpn ]; then
        pass "client1.ovpn bundle present (~/client-configs/files/client1.ovpn)"
    else
        fail "E14" "client1.ovpn not found — run the make_config.sh script"
        info "Check: ls ~/client-configs/files/"
    fi

    if [ -f ~/client-configs/base.conf ]; then
        local remote_line
        remote_line=$(grep '^remote ' ~/client-configs/base.conf 2>/dev/null)
        if echo "$remote_line" | grep -qE 'remote [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ 1194'; then
            pass "base.conf remote IP is set: $remote_line"
        else
            fail "E15" "base.conf remote line missing or still has placeholder: '$remote_line'"
            info "Update: remote [ETH0_IP] 1194  →  replace [ETH0_IP] with the External Gateway eth0 IP"
        fi
    else
        fail "E15" "~/client-configs/base.conf not found"
    fi
}

# =============================================================================
# External Gateway — UDP 1194 nftables rules
# =============================================================================
run_external_gateway() {
    echo -e "\n${BOLD}${CYAN}VM detected: External Gateway${NC}"

    local ruleset
    ruleset=$(nft list ruleset 2>/dev/null)

    # =========================================================================
    section "nftables Service and Persistence"
    # =========================================================================
    if systemctl is-active --quiet nftables 2>/dev/null; then
        pass "nftables service is active"
    else
        fail "E19" "nftables service is not active — run: sudo systemctl start nftables"
    fi

    if systemctl is-enabled --quiet nftables 2>/dev/null; then
        pass "nftables service is enabled (rules persist on reboot)"
    else
        fail "E19" "nftables service is not enabled — run: sudo systemctl enable nftables"
    fi

    if grep -q "1194" /etc/nftables.conf 2>/dev/null; then
        pass "/etc/nftables.conf contains UDP 1194 rules (persistent)"
    else
        fail "E19" "UDP 1194 rules not saved in /etc/nftables.conf — rules will be lost on reboot"
        info "Add the new rules to /etc/nftables.conf and run: sudo systemctl reload nftables"
    fi

    # =========================================================================
    section "Activity 4-1 Rules Still Present"
    # =========================================================================
    for port in 80 443 25; do
        if echo "$ruleset" | grep -q "tcp dport $port"; then
            pass "Existing port $port rule still present (Activity 4-1 rules intact)"
        else
            fail "E19" "Port $port rule is missing — Activity 4-1 rules may have been overwritten"
            info "Do NOT replace the existing ruleset — only add the new UDP 1194 rules"
        fi
    done

    # =========================================================================
    section "UDP 1194 Forward Rule"
    # =========================================================================
    if echo "$ruleset" | grep -A30 'chain forward' | grep -E 'udp dport 1194.*accept' >/dev/null; then
        pass "UDP 1194 forward rule present in forward chain"
    else
        fail "E16" "UDP 1194 forward rule missing from forward chain"
        info 'Add: iif "eth0" oif "eth1" udp dport 1194 ct state new accept'
    fi

    if echo "$ruleset" | grep -A30 'chain forward' | grep -E 'udp sport 1194.*accept' >/dev/null; then
        pass "UDP 1194 return forward rule present (udp sport 1194)"
    else
        fail "E16" "UDP 1194 return forward rule missing from forward chain"
        info 'Add: iif "eth1" oif "eth0" udp sport 1194 ct state established accept'
    fi

    # =========================================================================
    section "UDP 1194 DNAT Rule"
    # =========================================================================
    if echo "$ruleset" | grep -A20 'chain prerouting' | grep -E 'udp dport 1194.*dnat to 192\.168\.1\.1' >/dev/null; then
        pass "UDP 1194 DNAT rule forwards to 192.168.1.1 (Internal Gateway)"
    else
        fail "E17" "UDP 1194 DNAT rule missing from prerouting chain"
        info 'Add: iif "eth0" udp dport 1194 dnat to 192.168.1.1'
    fi

    # =========================================================================
    section "UDP 1194 SNAT Rule"
    # =========================================================================
    if echo "$ruleset" | grep -A20 'chain postrouting' | grep -E 'udp dport 1194.*snat to 192\.168\.1\.254' >/dev/null; then
        pass "UDP 1194 SNAT rule present for return traffic"
    else
        fail "E18" "UDP 1194 SNAT rule missing from postrouting chain"
        info 'Add: oif "eth1" udp dport 1194 ip daddr 192.168.1.1 snat to 192.168.1.254'
    fi

    # =========================================================================
    section "Live Connectivity Test"
    # =========================================================================
    info "Testing UDP 1194 reachability to Internal Gateway..."
    if (echo > /dev/udp/192.168.1.1/1194) 2>/dev/null; then
        pass "UDP 1194 reachable on Internal Gateway (192.168.1.1)"
    else
        warn "UDP 1194 socket test to 192.168.1.1 inconclusive — UDP is connectionless"
        info "Verify by connecting the VPN client and checking tun0 on the Internal Gateway"
    fi
}

# =============================================================================
# OpenVPN Client VM — client1.ovpn, tun0, VPN connectivity
# =============================================================================
run_openvpn_client() {
    echo -e "\n${BOLD}${CYAN}VM detected: OpenVPN Client VM${NC}"

    # =========================================================================
    section "OpenVPN Installation"
    # =========================================================================
    if command -v openvpn &>/dev/null; then
        pass "OpenVPN installed ($(openvpn --version 2>&1 | head -1))"
    else
        fail "E21" "OpenVPN not installed — run: sudo apt install openvpn -y"
    fi

    if dpkg -l network-manager-openvpn 2>/dev/null | grep -q '^ii'; then
        pass "Network Manager OpenVPN plugin installed"
    else
        warn "network-manager-openvpn not installed — needed for GUI import"
        info "Run: sudo apt install network-manager-openvpn network-manager-openvpn-gnome -y"
    fi

    if dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then
        pass "openssh-server installed (required for SCP transfer)"
    else
        warn "openssh-server not installed — SCP from Internal Gateway will fail"
        info "Run: sudo apt install openssh-server -y"
    fi

    # =========================================================================
    section "client1.ovpn File"
    # =========================================================================
    if [ -f ~/client1.ovpn ]; then
        pass "client1.ovpn present at ~/client1.ovpn"
        # Check it looks like a valid ovpn file
        if grep -q "^client" ~/client1.ovpn 2>/dev/null && grep -q "<ca>" ~/client1.ovpn 2>/dev/null; then
            pass "client1.ovpn appears valid (contains client directive and embedded CA)"
        else
            fail "E20" "client1.ovpn exists but may be incomplete — missing 'client' directive or embedded CA"
            info "Regenerate using make_config.sh on the Internal Gateway"
        fi
        # Check remote IP is not a placeholder
        local remote_line
        remote_line=$(grep '^remote ' ~/client1.ovpn 2>/dev/null)
        if echo "$remote_line" | grep -qE 'remote [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ 1194'; then
            pass "client1.ovpn remote IP is set: $remote_line"
        else
            fail "E20" "client1.ovpn remote line missing or has placeholder: '$remote_line'"
            info "Update base.conf on the Internal Gateway with the External Gateway eth0 IP and regenerate"
        fi
    else
        fail "E20" "client1.ovpn not found at ~/client1.ovpn"
        info "Transfer from Internal Gateway: scp ~/client-configs/files/client1.ovpn user@<CLIENT_VM_IP>:~/"
    fi

    # =========================================================================
    section "VPN Connection (tun0)"
    # =========================================================================
    if ip addr show tun0 &>/dev/null; then
        local tun_ip
        tun_ip=$(ip addr show tun0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if echo "$tun_ip" | grep -qE '^10\.8\.0\.[0-9]+$'; then
            pass "tun0 interface present with VPN IP: $tun_ip"
        else
            fail "E22" "tun0 exists but IP $tun_ip is not in 10.8.0.0/24"
        fi
    else
        fail "E22" "tun0 interface not present — VPN is not connected"
        info "Connect via: sudo openvpn --config ~/client1.ovpn"
        info "Or use Network Manager → VPN → Connect"
    fi

    # =========================================================================
    section "VPN Connectivity Tests"
    # =========================================================================
    if ip addr show tun0 &>/dev/null; then
        info "Testing ping to Internal Gateway tun0 (10.8.0.1)..."
        if ping -c 4 -W 3 10.8.0.1 &>/dev/null; then
            pass "Ping to Internal Gateway tun0 (10.8.0.1) — 0% packet loss"
        else
            fail "E23" "Ping to 10.8.0.1 failed — tunnel may be up but traffic not routing correctly"
            info "Check nftables forward rules on External Gateway for UDP 1194"
        fi

        info "Testing access to DMZ web server (192.168.1.80) via VPN..."
        if ping -c 2 -W 3 192.168.1.80 &>/dev/null; then
            pass "Ping to Ubuntu Server (192.168.1.80) via VPN successful"
        else
            fail "E24" "Cannot reach 192.168.1.80 via VPN"
            info "Check server.conf push route on Internal Gateway: push \"route 192.168.1.0 255.255.255.0\""
            info "Also check default route on Ubuntu Server points to 192.168.1.1 (not 192.168.1.254)"
        fi

        if curl -fsSL --max-time 5 -o /dev/null http://192.168.1.80 2>/dev/null; then
            pass "HTTP (port 80) reachable on 192.168.1.80 via VPN"
        else
            fail "E24" "HTTP not reachable on 192.168.1.80 via VPN — check Apache and routing"
        fi
    else
        warn "Skipping connectivity tests — VPN not connected (tun0 missing)"
    fi
}

# =============================================================================
# Ubuntu Server / Desktop — no changes in this activity
# =============================================================================
run_no_changes() {
    local vmname="$1"
    echo -e "\n${BOLD}${CYAN}VM detected: $vmname${NC}"
    echo ""
    echo -e "  ${CYAN}[INFO]${NC} No Activity 4-2 configuration changes are required on this VM."
    echo -e "  ${CYAN}[INFO]${NC} Run this script on the Internal Gateway, External Gateway,"
    echo -e "  ${CYAN}[INFO]${NC} or OpenVPN Client VM for relevant checks."
}

# =============================================================================
# Summary
# =============================================================================
print_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD} Summary${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Passed : ${GREEN}${PASS}${NC}"
    echo -e "  Failed : ${RED}${FAIL}${NC}"

    if [ ${#ERRORS[@]} -gt 0 ]; then
        local unique_errors
        unique_errors=$(printf '%s\n' "${ERRORS[@]}" | sort -u | tr '\n' ' ')
        echo ""
        echo -e "  ${RED}${BOLD}Errors detected: $unique_errors${NC}"
        echo -e "  ${YELLOW}Refer to the Troubleshooting section of the Activity 4-2 guide.${NC}"
        echo ""
    else
        echo ""
        echo -e "  ${GREEN}${BOLD}All checks passed! Activity 4-2 configuration looks correct.${NC}"
        echo ""
    fi
}

# =============================================================================
# Main
# =============================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Activity 4-2 Automarker — VPN with OpenVPN${NC}"
echo -e "${BOLD} 7015ICT | Griffith University${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

VM=$(detect_vm)

case "$VM" in
    internal_gateway)  run_internal_gateway ;;
    external_gateway)  run_external_gateway ;;
    openvpn_client)    run_openvpn_client ;;
    ubuntu_server)     run_no_changes "Ubuntu Server" ;;
    ubuntu_desktop)    run_no_changes "Ubuntu Desktop" ;;
    *)
        echo ""
        echo -e "${RED}[ERROR]${NC} Could not detect which VM this is."
        echo ""
        echo "        Expected addresses per VM:"
        echo "          Internal Gateway : 192.168.1.1 + 10.10.1.254"
        echo "          External Gateway : 192.168.1.254"
        echo "          Ubuntu Server    : 192.168.1.80"
        echo "          Ubuntu Desktop   : 10.10.1.1"
        echo "          OpenVPN Client   : DHCP (detected by openvpn presence)"
        echo ""
        echo "        Your current addresses:"
        ip -brief addr show 2>/dev/null | sed 's/^/          /'
        exit 1
        ;;
esac

print_summary
