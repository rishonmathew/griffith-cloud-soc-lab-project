#!/bin/bash
# =============================================================================
# Automarking Script - Activity 2.2: BIND9 DNS Server
# 3821ICT | Griffith University
# =============================================================================
# Run on Internal Gateway, Ubuntu Server, or Ubuntu Desktop.
# The script auto-detects which VM it is running on.
#
# Usage: sudo bash automark_activity2.2.sh
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "  [ERROR] Please run with sudo: sudo bash automark_activity2.2.sh"
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

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $2"; echo -e "         ${YELLOW}→ Error $1${NC}"; ERRORS+=("$1"); ((FAIL++)); }
info() { echo -e "  ${CYAN}[INFO]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
section() { echo ""; echo -e "${BOLD}--- $1 ---${NC}"; }

has_ip() { ip addr show 2>/dev/null | grep -q "inet $1"; }

# =============================================================================
# Detect VM
# =============================================================================
detect_vm() {
    if has_ip "192.168.1.1" && has_ip "10.10.1.254"; then
        echo "internal_gateway"
    elif has_ip "192.168.1.80"; then
        echo "ubuntu_server"
    elif has_ip "10.10.1.1"; then
        echo "ubuntu_desktop"
    else
        echo "unknown"
    fi
}

# =============================================================================
# Shared helpers
# =============================================================================

check_service_active() {
    local svc=$1 code=$2
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        pass "Service $svc is active"
    else
        fail "$code" "Service $svc is not running"
    fi
}

check_port_listening() {
    local port=$1 label=$2 code=$3
    if ss -tuln 2>/dev/null | grep -q ":$port "; then
        pass "$label listening on port $port"
    else
        fail "$code" "$label not listening on port $port"
    fi
}

check_internet() {
    local code=$1
    for url in "https://example.com" "https://www.google.com"; do
        local h
        h=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -L "$url" 2>/dev/null)
        if [[ "$h" =~ ^[23] ]]; then
            pass "Internet access confirmed (HTTP $h from $url)"
            return
        fi
    done
    fail "$code" "No internet access"
}

# =============================================================================
# Detect student domain from BIND9 config
# =============================================================================
detect_domain() {
    local zone
    zone=$(grep "^zone" /etc/bind/named.conf.local 2>/dev/null \
        | grep -v 'arpa\|localhost\|hint\|\"\.\"\|"."' \
        | grep '"' | head -1 \
        | sed 's/.*"\(.*\)".*/\1/')
    echo "$zone"
}

# =============================================================================
# Internal Gateway checks
# =============================================================================
run_internal_gateway() {
    echo -e "\n${BOLD}${CYAN}VM detected: Internal Gateway${NC}"

    local DOMAIN
    DOMAIN=$(detect_domain)

    section "BIND9 Service"
    if systemctl is-active --quiet named 2>/dev/null || systemctl is-active --quiet bind9 2>/dev/null; then
        pass "BIND9 (named) is running"
    else
        fail "B1" "BIND9 is not running — run: sudo systemctl restart named"
    fi
    check_port_listening "53" "BIND9" "B1"

    section "BIND9 Listen-on Configuration"
    local listenon
    listenon=$(grep "listen-on" /etc/bind/named.conf.options 2>/dev/null | grep -v v6 | head -1)
    if echo "$listenon" | grep -q "127.0.0.1"; then
        pass "listen-on includes 127.0.0.1"
    else
        fail "B2" "127.0.0.1 missing from listen-on in named.conf.options"
        info "Edit named.conf.options: listen-on { 127.0.0.1; 192.168.1.1; 10.10.1.254; };"
    fi
    if echo "$listenon" | grep -q "10.10.1.254"; then
        pass "listen-on includes 10.10.1.254"
    else
        fail "B2" "10.10.1.254 missing from listen-on in named.conf.options"
    fi

    section "Student Domain Detection"
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "." ]; then
        fail "B3" "No custom forward zone found in named.conf.local"
        info "Check /etc/bind/named.conf.local for your zone definition"
        DOMAIN=""
    else
        pass "Domain detected: $DOMAIN"
    fi

    section "Zone File Validation"
    if [ -n "$DOMAIN" ]; then
        local fwd_check
        fwd_check=$(named-checkzone "$DOMAIN" "/etc/bind/db.$DOMAIN" 2>&1)
        if echo "$fwd_check" | grep -q "^OK"; then
            pass "Forward zone file valid: db.$DOMAIN"
        else
            fail "B3" "Forward zone file invalid or missing: db.$DOMAIN"
            info "$fwd_check"
        fi
    else
        fail "B3" "Cannot check zone file — domain not detected"
    fi

    local rev_check
    rev_check=$(named-checkzone "1.168.192.in-addr.arpa" "/etc/bind/db.192.168.1" 2>&1)
    if echo "$rev_check" | grep -q "^OK"; then
        pass "Reverse zone file valid: db.192.168.1"
    else
        fail "B3" "Reverse zone file invalid or missing: db.192.168.1"
    fi

    section "DNS Forwarding (External)"
    local ext_result
    ext_result=$(dig @127.0.0.1 google.com +short +time=5 +tries=1 2>/dev/null | head -1)
    if [ -n "$ext_result" ]; then
        pass "External DNS forwarding works (google.com → $ext_result)"
    else
        fail "B4" "Cannot resolve external domains via BIND9 — check forwarders in named.conf.options"
    fi

    section "Local Zone Resolution"
    if [ -n "$DOMAIN" ]; then
        local fwd_ans
        fwd_ans=$(dig @127.0.0.1 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null)
        if [ "$fwd_ans" = "192.168.1.80" ]; then
            pass "Forward lookup: www.$DOMAIN → 192.168.1.80"
        else
            fail "B3" "www.$DOMAIN did not resolve to 192.168.1.80 (got: ${fwd_ans:-no response})"
        fi
    else
        fail "B3" "Cannot check forward lookup — domain not detected"
    fi

    section "Reverse Lookup"
    local rev_ans
    rev_ans=$(dig @127.0.0.1 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    if [ -n "$rev_ans" ]; then
        pass "Reverse lookup: 192.168.1.80 → $rev_ans"
    else
        fail "B3" "Reverse lookup for 192.168.1.80 returned no PTR record"
    fi

    section "DNSSEC"
    local dnssec_result
    dnssec_result=$(dig @127.0.0.1 dnssec-failed.org +time=5 +tries=1 2>/dev/null | grep "status:")
    if echo "$dnssec_result" | grep -qi "SERVFAIL"; then
        pass "DNSSEC validation active (dnssec-failed.org → SERVFAIL)"
    else
        warn "DNSSEC validation may not be enforcing (dnssec-failed.org did not return SERVFAIL)"
        info "Check: dnssec-validation yes; in named.conf.options"
    fi

    section "Connectivity"
    ping -c 2 -W 2 192.168.1.80 &>/dev/null && pass "Ping Ubuntu Server (192.168.1.80)" || fail "GEN" "Cannot ping Ubuntu Server"
    ping -c 2 -W 2 10.10.1.1 &>/dev/null && pass "Ping Ubuntu Desktop (10.10.1.1)" || fail "GEN" "Cannot ping Ubuntu Desktop"
    check_internet "GEN"
}

# =============================================================================
# Ubuntu Server checks
# =============================================================================
run_ubuntu_server() {
    echo -e "\n${BOLD}${CYAN}VM detected: Ubuntu Server${NC}"

    section "DNS Server Configuration"
    local dns_server
    dns_server=$(grep "addresses:" /etc/netplan/50-cloud-init.yaml 2>/dev/null | grep -v "192.168\|10.10" | grep "10\." | head -1 | tr -d ' []')
    if grep -q "10.10.1.254" /etc/netplan/50-cloud-init.yaml 2>/dev/null; then
        pass "Netplan DNS set to 10.10.1.254"
    else
        fail "C1" "DNS server 10.10.1.254 not found in /etc/netplan/50-cloud-init.yaml"
        info "Add nameservers: addresses: [10.10.1.254] under eth0 in netplan"
    fi

    section "DNS Resolution via Internal Gateway"
    local ext_result
    ext_result=$(dig @10.10.1.254 google.com +short +time=5 +tries=1 2>/dev/null | head -1)
    if [ -n "$ext_result" ]; then
        pass "External DNS via 10.10.1.254 works (google.com → $ext_result)"
    else
        fail "C1" "Cannot resolve google.com via 10.10.1.254"
        info "Check BIND9 is running on Internal Gateway and netplan is applied"
    fi

    section "Local Domain Resolution"
    # Try to detect domain from BIND9 on Internal Gateway
    local DOMAIN
    DOMAIN=$(dig @10.10.1.254 +short axfr 2>/dev/null | head -1)
    # Fallback: check resolv.conf or just test known PTR
    local ptr
    ptr=$(dig @10.10.1.254 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    if [ -n "$ptr" ]; then
        pass "Reverse lookup via 10.10.1.254: 192.168.1.80 → $ptr"
        # Extract domain from PTR
        DOMAIN=$(echo "$ptr" | sed 's/^www\.//' | sed 's/\.$//')
    else
        fail "C1" "Reverse lookup for 192.168.1.80 failed via 10.10.1.254"
    fi

    if [ -n "$DOMAIN" ]; then
        local fwd
        fwd=$(dig @10.10.1.254 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null)
        if [ "$fwd" = "192.168.1.80" ]; then
            pass "Forward lookup via 10.10.1.254: www.$DOMAIN → 192.168.1.80"
        else
            fail "C1" "www.$DOMAIN did not resolve via 10.10.1.254 (got: ${fwd:-no response})"
        fi
    fi

    section "Internet Access"
    check_internet "GEN"
}

# =============================================================================
# Ubuntu Desktop checks
# =============================================================================
run_ubuntu_desktop() {
    echo -e "\n${BOLD}${CYAN}VM detected: Ubuntu Desktop${NC}"

    section "DNS Resolution via Internal Gateway"
    local ext_result
    ext_result=$(dig @10.10.1.254 google.com +short +time=5 +tries=1 2>/dev/null | head -1)
    if [ -n "$ext_result" ]; then
        pass "External DNS via 10.10.1.254 works (google.com → $ext_result)"
    else
        fail "D1" "Cannot resolve google.com via 10.10.1.254"
        info "Check BIND9 is running on Internal Gateway and Desktop DNS is set to 10.10.1.254"
    fi

    section "Local Domain Resolution"
    local ptr
    ptr=$(dig @10.10.1.254 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    local DOMAIN=""
    if [ -n "$ptr" ]; then
        pass "Reverse lookup: 192.168.1.80 → $ptr"
        DOMAIN=$(echo "$ptr" | sed 's/^www\.//' | sed 's/\.$//')
    else
        fail "D1" "Reverse lookup for 192.168.1.80 failed"
    fi

    if [ -n "$DOMAIN" ]; then
        local fwd
        fwd=$(dig @10.10.1.254 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null)
        if [ "$fwd" = "192.168.1.80" ]; then
            pass "Forward lookup: www.$DOMAIN → 192.168.1.80"
        else
            fail "D1" "www.$DOMAIN did not resolve (got: ${fwd:-no response})"
        fi
    fi

    section "Web Server Accessible by Domain Name"
    if [ -n "$DOMAIN" ]; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
            --resolve "www.$DOMAIN:80:192.168.1.80" \
            "http://www.$DOMAIN" 2>/dev/null)
        if [[ "$http_code" =~ ^[23] ]]; then
            pass "HTTP $http_code — http://www.$DOMAIN loads"
        else
            fail "D2" "http://www.$DOMAIN did not load (HTTP: ${http_code:-no response})"
            info "Ensure DNS resolves and Apache is running on Ubuntu Server"
        fi

        local https_code
        https_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 \
            --resolve "www.$DOMAIN:443:192.168.1.80" \
            "https://www.$DOMAIN" 2>/dev/null)
        if [[ "$https_code" =~ ^[23] ]]; then
            pass "HTTPS $https_code — https://www.$DOMAIN loads"
        else
            fail "D2" "https://www.$DOMAIN did not load (HTTP: ${https_code:-no response})"
        fi
    else
        fail "D2" "Cannot test web access — domain not detected from DNS"
    fi

    section "Internet Access"
    check_internet "GEN"
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
        echo -e "  ${YELLOW}Refer to the Troubleshooting section of the activity guide.${NC}"
        echo ""
    else
        echo ""
        echo -e "  ${GREEN}${BOLD}All checks passed! Activity 2.2 configuration looks correct.${NC}"
        echo ""
    fi
}

# =============================================================================
# Main
# =============================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Activity 2.2 Automarker — BIND9 DNS Server${NC}"
echo -e "${BOLD} 3821ICT | Griffith University${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

VM=$(detect_vm)

case "$VM" in
    internal_gateway) run_internal_gateway ;;
    ubuntu_server)    run_ubuntu_server ;;
    ubuntu_desktop)   run_ubuntu_desktop ;;
    *)
        echo ""
        echo -e "${RED}[ERROR]${NC} Could not detect which VM this is."
        echo ""
        echo "        Expected IP addresses:"
        echo "          Internal Gateway — eth0 at 192.168.1.1 AND eth1 at 10.10.1.254"
        echo "          Ubuntu Server    — eth0 at 192.168.1.80"
        echo "          Ubuntu Desktop   — eth0 at 10.10.1.1"
        echo ""
        echo "        Your current addresses:"
        ip -brief addr show 2>/dev/null | sed 's/^/          /'
        exit 1
        ;;
esac

print_summary
