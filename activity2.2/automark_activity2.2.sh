#!/bin/bash
# =============================================================================
# Automarking Script - Activity 2.2: BIND9 DNS Server
# 3821ICT | Griffith University
# =============================================================================
# Usage: sudo bash automark_activity2.2.sh
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo ""; echo "  [ERROR] Please run with sudo: sudo bash automark_activity2.2.sh"; echo ""
    exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; ERRORS=()

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $2"; echo -e "         ${YELLOW}→ Error $1${NC}"; ERRORS+=("$1"); ((FAIL++)); }
info() { echo -e "  ${CYAN}[INFO]${NC} $1"; }
section() { echo ""; echo -e "${BOLD}--- $1 ---${NC}"; }
has_ip() { ip addr show 2>/dev/null | grep -q "inet $1"; }

detect_vm() {
    if has_ip "192.168.1.1" && has_ip "10.10.1.254"; then echo "internal_gateway"
    elif has_ip "192.168.1.80"; then echo "ubuntu_server"
    elif has_ip "10.10.1.1"; then echo "ubuntu_desktop"
    else echo "unknown"; fi
}

check_internet() {
    local code=$1
    for url in "https://example.com" "https://www.google.com"; do
        local h; h=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -L "$url" 2>/dev/null)
        if [[ "$h" =~ ^[23] ]]; then pass "Internet access confirmed (HTTP $h from $url)"; return; fi
    done
    fail "$code" "No internet access"
}

detect_domain() {
    grep "^zone" /etc/bind/named.conf.local 2>/dev/null \
        | grep -v 'arpa\|localhost\|hint\|"\."' \
        | grep '"' | head -1 | sed 's/.*"\(.*\)".*/\1/'
}

# =============================================================================
run_internal_gateway() {
    echo -e "\n${BOLD}${CYAN}VM detected: Internal Gateway${NC}"

    section "BIND9 Service"
    if systemctl is-active --quiet named 2>/dev/null || systemctl is-active --quiet bind9 2>/dev/null; then
        pass "BIND9 (named) is running"
    else
        fail "B1" "BIND9 is not running — sudo systemctl restart named"
    fi
    ss -tuln 2>/dev/null | grep -q ":53 " && pass "BIND9 listening on port 53" \
        || fail "B1" "BIND9 not listening on port 53"

    section "listen-on Configuration"
    local listenon
    listenon=$(grep "listen-on" /etc/bind/named.conf.options 2>/dev/null | grep -v v6 | head -1)
    for addr in "127.0.0.1" "192.168.1.1" "10.10.1.254"; do
        if echo "$listenon" | grep -q "$addr"; then
            pass "listen-on includes $addr"
        else
            fail "B2" "$addr missing from listen-on in named.conf.options"
        fi
    done

    section "Student Domain"
    local DOMAIN; DOMAIN=$(detect_domain)
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "." ]; then
        fail "B3" "No custom forward zone found in /etc/bind/named.conf.local"
        DOMAIN=""
    else
        pass "Domain detected: $DOMAIN"
    fi

    section "Zone File Validation"
    if [ -n "$DOMAIN" ]; then
        if named-checkzone "$DOMAIN" "/etc/bind/db.$DOMAIN" > /dev/null 2>&1; then
            pass "Forward zone file valid: db.$DOMAIN"
        else
            fail "B3" "Forward zone file invalid or missing: db.$DOMAIN"
        fi
    else
        fail "B3" "Cannot check forward zone — domain not detected"
    fi
    if named-checkzone "1.168.192.in-addr.arpa" "/etc/bind/db.192.168.1" > /dev/null 2>&1; then
        pass "Reverse zone file valid: db.192.168.1"
    else
        fail "B3" "Reverse zone file invalid or missing: db.192.168.1"
    fi

    section "External DNS Forwarding"
    local ext; ext=$(dig @127.0.0.1 google.com +short +time=5 +tries=1 2>/dev/null | grep -E '^[0-9]' | head -1)
    [ -n "$ext" ] && pass "External DNS forwarding works (google.com → $ext)" \
        || fail "B4" "Cannot resolve external domains — check forwarders and 'forward only' in named.conf.options"

    section "Local Zone — Forward Lookup"
    if [ -n "$DOMAIN" ]; then
        local fwd; fwd=$(dig @127.0.0.1 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null)
        [ "$fwd" = "192.168.1.80" ] && pass "Forward lookup: www.$DOMAIN → 192.168.1.80" \
            || fail "B3" "www.$DOMAIN → expected 192.168.1.80, got: ${fwd:-no response}"
    else
        fail "B3" "Cannot check forward lookup — domain not detected"
    fi

    section "Local Zone — Reverse Lookup"
    local rev; rev=$(dig @127.0.0.1 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    [ -n "$rev" ] && pass "Reverse lookup: 192.168.1.80 → $rev" \
        || fail "B3" "Reverse lookup for 192.168.1.80 returned no PTR record"

    section "DNSSEC Validation"
    local dnssec; dnssec=$(dig @127.0.0.1 dnssec-failed.org +time=5 +tries=1 2>/dev/null | grep "status:")
    if echo "$dnssec" | grep -qi "SERVFAIL"; then
        pass "DNSSEC active — dnssec-failed.org → SERVFAIL"
    else
        fail "B5" "DNSSEC not enforcing — dnssec-failed.org did not return SERVFAIL"
        info "Check: dnssec-validation yes; in named.conf.options, then restart named"
    fi

    section "Connectivity"
    ping -c 2 -W 2 192.168.1.80 &>/dev/null && pass "Ping Ubuntu Server (192.168.1.80)" \
        || fail "GEN" "Cannot ping Ubuntu Server (192.168.1.80)"
    ping -c 2 -W 2 10.10.1.1 &>/dev/null && pass "Ping Ubuntu Desktop (10.10.1.1)" \
        || fail "GEN" "Cannot ping Ubuntu Desktop (10.10.1.1)"
    check_internet "GEN"
}

# =============================================================================
run_ubuntu_server() {
    echo -e "\n${BOLD}${CYAN}VM detected: Ubuntu Server${NC}"

    section "Netplan DNS Configuration"
    # Ubuntu Server is on the DMZ — uses 192.168.1.1 (Internal Gateway DMZ interface)
    if grep -q "192.168.1.1" /etc/netplan/50-cloud-init.yaml 2>/dev/null; then
        pass "Netplan DNS set to 192.168.1.1"
    else
        fail "C1" "DNS 192.168.1.1 not found in /etc/netplan/50-cloud-init.yaml"
        info "Add nameservers: addresses: [192.168.1.1] under eth0 and run: sudo netplan apply"
    fi

    section "DNS Resolution via BIND9"
    local ext; ext=$(dig @192.168.1.1 google.com +short +time=5 +tries=1 2>/dev/null | grep -E '^[0-9]' | head -1)
    [ -n "$ext" ] && pass "External DNS via 192.168.1.1 works (google.com → $ext)" \
        || fail "C1" "Cannot resolve google.com via 192.168.1.1 — check BIND9 on Internal Gateway"

    section "Local Zone Resolution"
    local rev; rev=$(dig @192.168.1.1 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    if [ -n "$rev" ]; then
        pass "Reverse lookup via 192.168.1.1: 192.168.1.80 → $rev"
        local DOMAIN; DOMAIN=$(echo "$rev" | sed 's/^www\.//' | sed 's/\.$//')
        local fwd; fwd=$(dig @192.168.1.1 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null)
        [ "$fwd" = "192.168.1.80" ] && pass "Forward lookup via 192.168.1.1: www.$DOMAIN → 192.168.1.80" \
            || fail "C1" "Forward lookup failed for www.$DOMAIN (got: ${fwd:-no response})"
    else
        fail "C1" "Reverse lookup for 192.168.1.80 failed via 192.168.1.1"
    fi

    section "Internet Access"
    check_internet "GEN"
}

# =============================================================================
run_ubuntu_desktop() {
    echo -e "\n${BOLD}${CYAN}VM detected: Ubuntu Desktop${NC}"

    section "DNS Resolution via BIND9"
    local ext; ext=$(dig @10.10.1.254 google.com +short +time=5 +tries=1 2>/dev/null | grep -E '^[0-9]' | head -1)
    [ -n "$ext" ] && pass "External DNS via 10.10.1.254 works (google.com → $ext)" \
        || fail "D1" "Cannot resolve google.com via 10.10.1.254"

    section "Local Zone Resolution"
    local DOMAIN=""
    local rev; rev=$(dig @10.10.1.254 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    if [ -n "$rev" ]; then
        pass "Reverse lookup: 192.168.1.80 → $rev"
        DOMAIN=$(echo "$rev" | sed 's/^www\.//' | sed 's/\.$//')
        local fwd; fwd=$(dig @10.10.1.254 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null)
        [ "$fwd" = "192.168.1.80" ] && pass "Forward lookup: www.$DOMAIN → 192.168.1.80" \
            || fail "D1" "www.$DOMAIN did not resolve (got: ${fwd:-no response})"
    else
        fail "D1" "Reverse lookup for 192.168.1.80 failed via 10.10.1.254"
    fi

    section "Web Server Access by Domain Name"
    if [ -n "$DOMAIN" ]; then
        # Confirm DNS resolves correctly before testing web — no --resolve bypass
        local resolved
        resolved=$(dig @10.10.1.254 "www.$DOMAIN" +short +time=5 +tries=1 2>/dev/null \
                   | grep -E '^[0-9]' | head -1)
        if [ "$resolved" != "192.168.1.80" ]; then
            fail "D2" "DNS does not resolve www.$DOMAIN — fix DNS before testing web access"
        else
            local http_code
            http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
                        "http://www.$DOMAIN" 2>/dev/null)
            [[ "$http_code" =~ ^[23] ]] \
                && pass "HTTP $http_code — http://www.$DOMAIN loads via DNS" \
                || fail "D2" "http://www.$DOMAIN did not load (HTTP: ${http_code:-no response})"

            local https_code
            https_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 \
                         "https://www.$DOMAIN" 2>/dev/null)
            [[ "$https_code" =~ ^[23] ]] \
                && pass "HTTPS $https_code — https://www.$DOMAIN loads via DNS" \
                || fail "D2" "https://www.$DOMAIN did not load (HTTP: ${https_code:-no response})"
        fi
    else
        fail "D2" "Cannot test web access — domain not detected from DNS"
    fi

    section "Internet Access"
    check_internet "GEN"
}

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
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Activity 2.2 Automarker — BIND9 DNS Server${NC}"
echo -e "${BOLD} 3821ICT | Griffith University${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

case "$(detect_vm)" in
    internal_gateway) run_internal_gateway ;;
    ubuntu_server)    run_ubuntu_server ;;
    ubuntu_desktop)   run_ubuntu_desktop ;;
    *)
        echo ""
        echo -e "${RED}[ERROR]${NC} Could not detect which VM this is."
        echo "  Internal Gateway — 192.168.1.1 AND 10.10.1.254"
        echo "  Ubuntu Server    — 192.168.1.80"
        echo "  Ubuntu Desktop   — 10.10.1.1"
        echo ""
        ip -brief addr show 2>/dev/null | sed 's/^/  /'
        exit 1
        ;;
esac

print_summary