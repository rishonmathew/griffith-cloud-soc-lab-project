#!/bin/bash
# =============================================================================
# Automarking Script - Activity 4-2: VPN with OpenVPN
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "Run with:"
    echo "sudo bash automark_activity4.2.sh"
    echo ""
    exit 1
fi

# -----------------------------------------------------------------------------
# IMPORTANT FIX
# -----------------------------------------------------------------------------
REAL_USER="${SUDO_USER:-user}"
USER_HOME=$(eval echo "~$REAL_USER")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

section() {
    echo ""
    echo -e "${BOLD}--- $1 ---${NC}"
}

has_ip() {
    ip addr show 2>/dev/null | grep -q "$1"
}

detect_vm() {

    if has_ip "192.168.1.1" && has_ip "10.10.1.254"; then
        echo "internal_gateway"
        return
    fi

    if has_ip "192.168.1.254"; then
        echo "external_gateway"
        return
    fi

    if command -v openvpn >/dev/null 2>&1; then
        echo "openvpn_client"
        return
    fi

    echo "unknown"
}

run_internal_gateway() {

    echo ""
    echo -e "${BOLD}${CYAN}VM detected: Internal Gateway${NC}"

    OPENVPN_CA="$USER_HOME/openvpn-ca"
    CLIENT_CONFIGS="$USER_HOME/client-configs"

    # -------------------------------------------------------------------------
    section "OpenVPN Installation"

    if command -v openvpn >/dev/null 2>&1; then
        pass "OpenVPN installed"
    else
        fail "OpenVPN not installed"
    fi

    if [ -f "$OPENVPN_CA/easyrsa" ]; then
        pass "Easy-RSA present"
    else
        fail "Easy-RSA missing"
    fi

    if [ -f "$OPENVPN_CA/vars" ]; then
        pass "vars file present"
    else
        fail "vars file missing"
    fi

    # -------------------------------------------------------------------------
    section "PKI"

    if [ -d "$OPENVPN_CA/pki" ]; then
        pass "PKI directory exists"
    else
        fail "PKI not initialised"
    fi

    if [ -f "$OPENVPN_CA/pki/ca.crt" ]; then
        pass "CA certificate exists"
    else
        fail "CA certificate missing"
    fi

    if [ -f "$OPENVPN_CA/pki/issued/server.crt" ]; then
        pass "Server certificate exists"
    else
        fail "Server certificate missing"
    fi

    if [ -f "$OPENVPN_CA/pki/private/server.key" ]; then
        pass "Server key exists"
    else
        fail "Server key missing"
    fi

    if [ -f "$OPENVPN_CA/pki/dh.pem" ]; then
        pass "DH parameters exist"
    else
        fail "DH parameters missing"
    fi

    if [ -f "$OPENVPN_CA/ta.key" ]; then
        pass "TLS auth key exists"
    else
        fail "TLS auth key missing"
    fi

    # -------------------------------------------------------------------------
    section "Files Copied to /etc/openvpn"

    for f in ca.crt server.crt server.key dh2048.pem ta.key
    do
        if [ -f "/etc/openvpn/$f" ]; then
            pass "$f present"
        else
            fail "$f missing from /etc/openvpn"
        fi
    done

    # -------------------------------------------------------------------------
    section "server.conf"

    if [ -f /etc/openvpn/server.conf ]; then

        pass "server.conf exists"

        CONF=$(cat /etc/openvpn/server.conf)

        for directive in \
            "port 1194" \
            "proto udp" \
            "dev tun" \
            "server 10.8.0.0" \
            "tls-auth ta.key"
        do
            if echo "$CONF" | grep -q "$directive"; then
                pass "$directive found"
            else
                fail "$directive missing"
            fi
        done

    else
        fail "server.conf missing"
    fi

    # -------------------------------------------------------------------------
    section "IP Forwarding"

    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
        pass "IP forwarding enabled"
    else
        fail "IP forwarding disabled"
    fi

    # FIXED GREP
    if grep -Eq "net.ipv4.ip_forward *= *1" /etc/sysctl.conf; then
        pass "Persistent IP forwarding configured"
    else
        fail "Persistent IP forwarding missing"
    fi

    # -------------------------------------------------------------------------
    section "OpenVPN Service"

    if systemctl is-active --quiet openvpn@server; then
        pass "OpenVPN service active"
    else
        fail "OpenVPN service not running"
    fi

    if systemctl is-enabled --quiet openvpn@server; then
        pass "OpenVPN service enabled"
    else
        fail "OpenVPN service not enabled"
    fi

    # -------------------------------------------------------------------------
    section "tun0 Interface"

    if ip addr show tun0 >/dev/null 2>&1; then

        TUNIP=$(ip addr show tun0 | grep inet | awk '{print $2}' | cut -d/ -f1)

        if [ "$TUNIP" = "10.8.0.1" ]; then
            pass "tun0 has correct IP"
        else
            fail "tun0 incorrect IP ($TUNIP)"
        fi

    else
        fail "tun0 missing"
    fi

    # -------------------------------------------------------------------------
    section "Client Certificates"

    if [ -f "$OPENVPN_CA/pki/issued/client1.crt" ]; then
        pass "client1.crt exists"
    else
        fail "client1.crt missing"
    fi

    if [ -f "$OPENVPN_CA/pki/private/client1.key" ]; then
        pass "client1.key exists"
    else
        fail "client1.key missing"
    fi

    if [ -f "$CLIENT_CONFIGS/files/client1.ovpn" ]; then
        pass "client1.ovpn exists"
    else
        fail "client1.ovpn missing"
    fi

    if [ -f "$CLIENT_CONFIGS/base.conf" ]; then

        REMOTE=$(grep '^remote ' "$CLIENT_CONFIGS/base.conf")

        if echo "$REMOTE" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
            pass "base.conf remote IP configured"
        else
            fail "base.conf remote IP incorrect"
        fi

    else
        fail "base.conf missing"
    fi
}

run_external_gateway() {

    echo ""
    echo -e "${BOLD}${CYAN}VM detected: External Gateway${NC}"

    RULESET=$(nft list ruleset 2>/dev/null)

    section "nftables"

    if echo "$RULESET" | grep -q "udp dport 1194"; then
        pass "UDP 1194 rules present"
    else
        fail "UDP 1194 rules missing"
    fi

    if echo "$RULESET" | grep -q "dnat to 192.168.1.1"; then
        pass "DNAT rule present"
    else
        fail "DNAT rule missing"
    fi

    if echo "$RULESET" | grep -q "snat to 192.168.1.254"; then
        pass "SNAT rule present"
    else
        fail "SNAT rule missing"
    fi
}

run_openvpn_client() {

    echo ""
    echo -e "${BOLD}${CYAN}VM detected: OpenVPN Client${NC}"

    section "OpenVPN"

    if command -v openvpn >/dev/null 2>&1; then
        pass "OpenVPN installed"
    else
        fail "OpenVPN missing"
    fi

    if [ -f "$USER_HOME/client1.ovpn" ]; then
        pass "client1.ovpn present"
    else
        fail "client1.ovpn missing"
    fi

    section "VPN Connection"

    if ip addr show tun0 >/dev/null 2>&1; then

        TUNIP=$(ip addr show tun0 | grep inet | awk '{print $2}' | cut -d/ -f1)

        if echo "$TUNIP" | grep -q "^10.8.0."; then
            pass "tun0 connected ($TUNIP)"
        else
            fail "tun0 incorrect IP"
        fi

        if ping -c 2 10.8.0.1 >/dev/null 2>&1; then
            pass "Ping to Internal Gateway successful"
        else
            fail "Cannot ping Internal Gateway"
        fi

    else
        fail "VPN not connected"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "${BOLD} Activity 4-2 VPN Automarker (FIXED)${NC}"
echo -e "${BOLD}=============================================${NC}"

VM=$(detect_vm)

case "$VM" in

    internal_gateway)
        run_internal_gateway
        ;;

    external_gateway)
        run_external_gateway
        ;;

    openvpn_client)
        run_openvpn_client
        ;;

    *)
        echo ""
        fail "Could not detect VM"
        ;;
esac

echo ""
echo -e "${BOLD}=============================================${NC}"
echo -e "PASS: ${GREEN}$PASS${NC}"
echo -e "FAIL: ${RED}$FAIL${NC}"
echo -e "${BOLD}=============================================${NC}"
echo ""
