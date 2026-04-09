#!/bin/bash
# =============================================================================
# Automarking Script - Activity 2: NAT, DNS, SSL, Proxy
# 3821ICT | Griffith University
# =============================================================================
# Run this script on any of the four lab VMs after completing the activity.
# The script will auto-detect which VM it is running on and perform the
# appropriate checks. Any failures are reported as numbered error codes.
#
# Usage: sudo ./automark_activity2.sh
# =============================================================================

# --- Enforce root ---
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "  [ERROR] This script must be run with sudo."
    echo "          Usage: sudo ./automark_activity2.sh"
    echo ""
    exit 1
fi

# --- Colour codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
ERRORS=()

# =============================================================================
# Helper functions
# =============================================================================

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    local code=$1
    local msg=$2
    echo -e "  ${RED}[FAIL]${NC} $msg"
    echo -e "         ${YELLOW}→ Error $code${NC}"
    ERRORS+=("$code")
    ((FAIL++))
}

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

section() {
    echo ""
    echo -e "${BOLD}--- $1 ---${NC}"
}

diag_ip() {
    echo -e "         ${CYAN}[DIAG] Current addresses:${NC}"
    ip -brief addr show 2>/dev/null | sed 's/^/                /'
}

diag_nft() {
    echo -e "         ${CYAN}[DIAG] Current nft ruleset:${NC}"
    nft list ruleset 2>/dev/null | sed 's/^/                /' | head -60
}

has_ip() {
    ip addr show 2>/dev/null | grep -q "inet $1"
}

# =============================================================================
# Detect which VM this is
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
        echo "unknown"
    fi
}

# =============================================================================
# Shared check functions
# =============================================================================

check_service_active() {
    local service=$1
    local error_code=$2
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        pass "Service $service is active"
    else
        fail "$error_code" "Service $service is not running"
        info "Fix: sudo systemctl enable --now $service"
    fi
}

check_port_listening() {
    local port=$1
    local label=$2
    local error_code=$3
    if ss -tuln 2>/dev/null | grep -q ":$port "; then
        pass "$label listening on port $port"
    else
        fail "$error_code" "$label not listening on port $port"
    fi
}

check_ping() {
    local target=$1
    local label=$2
    local error_code=$3
    if ping -c 2 -W 2 "$target" &>/dev/null; then
        pass "Ping $label ($target)"
    else
        fail "$error_code" "Cannot ping $label ($target)"
    fi
}

check_http() {
    local url=$1
    local label=$2
    local error_code=$3
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$url" 2>/dev/null)
    if [[ "$http_code" =~ ^[23] ]]; then
        pass "HTTP $http_code from $label ($url)"
    else
        fail "$error_code" "Cannot reach $label ($url) — HTTP code: ${http_code:-no response}"
    fi
}

check_https_insecure() {
    # Use -k to skip cert validation (self-signed certs are expected)
    local url=$1
    local label=$2
    local error_code=$3
    local http_code
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 "$url" 2>/dev/null)
    if [[ "$http_code" =~ ^[23] ]]; then
        pass "HTTPS $http_code from $label ($url)"
    else
        fail "$error_code" "Cannot reach $label via HTTPS ($url) — HTTP code: ${http_code:-no response}"
    fi
}

check_internet() {
    local error_code=$1
    local urls=("https://example.com" "https://www.google.com" "https://1.1.1.1")
    for url in "${urls[@]}"; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -L "$url" 2>/dev/null)
        if [[ "$http_code" =~ ^[23] ]]; then
            pass "Internet access confirmed (HTTP $http_code from $url)"
            return
        fi
    done
    fail "$error_code" "No internet access — tried ${urls[*]}"
}

# =============================================================================
# nftables checks — External Gateway (Activity 2 ruleset)
# =============================================================================

check_nft_service() {
    local error_code=$1
    if systemctl is-active --quiet nftables 2>/dev/null; then
        pass "nftables service is active"
    else
        fail "$error_code" "nftables service is not running"
    fi
}

get_nft_normalised() {
    nft list ruleset 2>/dev/null | tr -s ' \t\n' ' '
}

check_nft_masquerade() {
    local error_code=$1
    local n
    n=$(get_nft_normalised)
    if echo "$n" | grep -qE 'oif[[:space:]]+"eth0"[[:space:]]+masquerade'; then
        pass "nftables NAT masquerade: oif eth0 masquerade"
    else
        fail "$error_code" "nftables masquerade rule missing or not on eth0"
        diag_nft
    fi
}

check_nft_dnat_http() {
    local error_code=$1
    local n
    n=$(get_nft_normalised)
    # Accept either single port or combined port set containing 80
    if echo "$n" | grep -qE 'dport[[:space:]]+(80|[{][^}]*80[^}]*[}])[[:space:]]+dnat[[:space:]]+to[[:space:]]+192\.168\.1\.80'; then
        pass "nftables DNAT rule: port 80 → 192.168.1.80"
    else
        fail "$error_code" "DNAT rule for port 80 → 192.168.1.80 not found"
        diag_nft
    fi
}

check_nft_dnat_https() {
    local error_code=$1
    local n
    n=$(get_nft_normalised)
    if echo "$n" | grep -qE 'dport[[:space:]]+(443|[{][^}]*443[^}]*[}])[[:space:]]+dnat[[:space:]]+to[[:space:]]+192\.168\.1\.80'; then
        pass "nftables DNAT rule: port 443 → 192.168.1.80"
    else
        fail "$error_code" "DNAT rule for port 443 → 192.168.1.80 not found"
        diag_nft
    fi
}

check_nft_forward_inbound() {
    local error_code=$1
    local n
    n=$(get_nft_normalised)
    # Should have a forward rule allowing inbound to DMZ on 80/443
    if echo "$n" | grep -qE 'iif[[:space:]]+"eth0"[[:space:]]+oif[[:space:]]+"eth1"'; then
        pass "nftables forward rule: eth0 → eth1 (inbound to DMZ)"
    else
        fail "$error_code" "Forward rule for inbound traffic eth0 → eth1 not found"
        diag_nft
    fi
}

check_nft_forward_dmz_out() {
    local error_code=$1
    local n
    n=$(get_nft_normalised)
    if echo "$n" | grep -qE 'iif[[:space:]]+"eth1"[[:space:]]+oif[[:space:]]+"eth0"[[:space:]]+accept'; then
        pass "nftables forward rule: eth1 → eth0 (DMZ to internet)"
    else
        fail "$error_code" "Forward rule eth1 → eth0 accept not found"
        diag_nft
    fi
}

# =============================================================================
# BIND9 checks — Internal Gateway
# =============================================================================

check_bind9_running() {
    local error_code=$1
    if systemctl is-active --quiet named 2>/dev/null || systemctl is-active --quiet bind9 2>/dev/null; then
        pass "BIND9 (named) is running"
    else
        fail "$error_code" "BIND9 (named) is not running"
        info "Fix: sudo systemctl enable --now named"
    fi
}

check_dnssec_validation() {
    local error_code=$1
    local result
    result=$(dig @127.0.0.1 dnssec-failed.org +time=5 +tries=1 2>/dev/null | grep -i "SERVFAIL\|status:")
    if echo "$result" | grep -qi "SERVFAIL"; then
        pass "DNSSEC validation active (dnssec-failed.org → SERVFAIL)"
    else
        fail "$error_code" "DNSSEC validation not enforcing — dnssec-failed.org did not return SERVFAIL"
        info "Re-check named.conf.options: dnssec-validation yes; must be set"
    fi
}

check_dnssec_ad_flag() {
    local error_code=$1
    local result
    result=$(dig @127.0.0.1 google.com +dnssec +time=5 +tries=1 2>/dev/null)
    if echo "$result" | grep -q " ad "; then
        pass "DNSSEC ad flag present for google.com"
    else
        warn "DNSSEC ad flag not present for google.com (may be expected in Azure TCP-forwarding environment)"
        info "Use dnssec-failed.org SERVFAIL as definitive proof of DNSSEC enforcement"
    fi
}

check_local_zone_resolves() {
    local error_code=$1
    # Detect the student's zone by parsing named.conf or zone files
    local zone_name
    zone_name=$(grep -r "^zone" /etc/bind/named.conf* 2>/dev/null | grep -v "arpa\|localhost\|hint\|0.0.127" | grep '"' | head -1 | sed 's/.*"\(.*\)".*/\1/')

    if [ -z "$zone_name" ]; then
        fail "$error_code" "No custom forward zone found in BIND9 config"
        info "Check /etc/bind/named.conf.local for your zone definition"
        return
    fi

    info "Detected zone: $zone_name"

    local result
    result=$(dig @127.0.0.1 "www.$zone_name" +short +time=5 +tries=1 2>/dev/null)
    if [ "$result" = "192.168.1.80" ]; then
        pass "Local zone resolves: www.$zone_name → 192.168.1.80"
    else
        fail "$error_code" "www.$zone_name did not resolve to 192.168.1.80 (got: ${result:-no response})"
        info "Check your zone file and restart named"
    fi
}

check_reverse_lookup() {
    local error_code=$1
    local result
    result=$(dig @127.0.0.1 -x 192.168.1.80 +short +time=5 +tries=1 2>/dev/null)
    if [ -n "$result" ]; then
        pass "Reverse lookup: 192.168.1.80 → $result"
    else
        fail "$error_code" "Reverse lookup for 192.168.1.80 returned no PTR record"
        info "Check your reverse zone file in /etc/bind/"
    fi
}

check_external_dns_forwarding() {
    local error_code=$1
    local result
    result=$(dig @127.0.0.1 google.com +short +time=8 +tries=1 2>/dev/null | head -1)
    if [ -n "$result" ]; then
        pass "External DNS forwarding works (google.com → $result)"
    else
        fail "$error_code" "BIND9 cannot forward external queries — no response for google.com"
        info "Check forwarders in named.conf.options and internet connectivity"
    fi
}

# =============================================================================
# Squid checks — Internal Gateway
# =============================================================================

check_squid_port() {
    local error_code=$1
    if ss -tuln 2>/dev/null | grep -q ":8080 "; then
        pass "Squid listening on port 8080"
    else
        fail "$error_code" "Squid not listening on port 8080"
        info "Check http_port in /etc/squid/squid.conf, then restart squid"
    fi
}

check_squid_acl_internal() {
    local error_code=$1
    if grep -q "^acl internal_network src 10.10.1.0/24" /etc/squid/squid.conf 2>/dev/null; then
        pass "Squid ACL: internal_network defined (10.10.1.0/24)"
    else
        fail "$error_code" "Squid ACL 'internal_network src 10.10.1.0/24' not found in squid.conf"
    fi
}

check_squid_acl_australian() {
    local error_code=$1
    if grep -q "^acl australian_sites dstdomain" /etc/squid/squid.conf 2>/dev/null; then
        pass "Squid ACL: australian_sites defined"
    else
        fail "$error_code" "Squid ACL 'australian_sites' not found in squid.conf"
    fi
}

check_squid_acl_office_hours() {
    local error_code=$1
    if grep -q "^acl office_hours time" /etc/squid/squid.conf 2>/dev/null; then
        pass "Squid ACL: office_hours defined"
    else
        fail "$error_code" "Squid ACL 'office_hours' not found in squid.conf"
    fi
}

check_squid_allow_internal() {
    local error_code=$1
    if grep -q "^http_access allow internal_network" /etc/squid/squid.conf 2>/dev/null; then
        pass "Squid rule: http_access allow internal_network present"
    else
        fail "$error_code" "Squid rule 'http_access allow internal_network' missing from squid.conf"
    fi
}

check_squid_deny_australian() {
    local error_code=$1
    if grep -q "^http_access deny australian_sites office_hours" /etc/squid/squid.conf 2>/dev/null; then
        pass "Squid rule: http_access deny australian_sites office_hours present"
    else
        fail "$error_code" "Squid rule 'http_access deny australian_sites office_hours' missing"
    fi
}

check_squid_rule_order() {
    local error_code=$1
    local deny_line allow_line
    deny_line=$(grep -n "^http_access deny australian_sites" /etc/squid/squid.conf 2>/dev/null | head -1 | cut -d: -f1)
    allow_line=$(grep -n "^http_access allow internal_network" /etc/squid/squid.conf 2>/dev/null | head -1 | cut -d: -f1)

    if [ -z "$deny_line" ] || [ -z "$allow_line" ]; then
        fail "$error_code" "Cannot verify rule order — one or both ACL rules are missing"
        return
    fi

    if [ "$deny_line" -lt "$allow_line" ]; then
        pass "Squid ACL rule order correct (deny australian_sites before allow internal_network)"
    else
        fail "$error_code" "Squid ACL rule order wrong — 'allow internal_network' appears before 'deny australian_sites'"
        info "The deny rule must come first or Australian sites will bypass the block"
    fi
}

# =============================================================================
# Apache/SSL checks — Ubuntu Server
# =============================================================================

check_ssl_cert_exists() {
    local error_code=$1
    if [ -f /etc/ssl/certs/apache-selfsigned.crt ] && [ -f /etc/ssl/private/apache-selfsigned.key ]; then
        pass "SSL certificate and key files exist"
    else
        fail "$error_code" "SSL cert or key missing"
        info "Expected: /etc/ssl/certs/apache-selfsigned.crt and /etc/ssl/private/apache-selfsigned.key"
    fi
}

check_ssl_params_conf() {
    local error_code=$1
    if [ -f /etc/apache2/conf-available/ssl-params.conf ]; then
        pass "ssl-params.conf exists"
    else
        fail "$error_code" "ssl-params.conf not found in /etc/apache2/conf-available/"
    fi
}

check_ssl_vhost_conf() {
    local error_code=$1
    if apache2ctl -S 2>/dev/null | grep -q ":443"; then
        pass "Apache SSL virtual host configured on port 443"
    else
        fail "$error_code" "No Apache virtual host found on port 443"
        info "Check /etc/apache2/sites-enabled/default-ssl.conf and run: sudo a2ensite default-ssl"
    fi
}

check_apache_modules() {
    local error_code=$1
    local missing=()
    for mod in ssl headers; do
        if ! apache2ctl -M 2>/dev/null | grep -q "${mod}_module"; then
            missing+=("$mod")
        fi
    done
    if [ ${#missing[@]} -eq 0 ]; then
        pass "Apache modules enabled: ssl, headers"
    else
        fail "$error_code" "Apache module(s) not enabled: ${missing[*]}"
        info "Fix: sudo a2enmod ${missing[*]} && sudo systemctl restart apache2"
    fi
}

check_custom_webpage() {
    local error_code=$1
    local content
    content=$(curl -sk --max-time 5 "http://192.168.1.80" 2>/dev/null)
    # Check it's not the default Apache page
    if echo "$content" | grep -qi "Apache2 Ubuntu Default Page\|It works!"; then
        fail "$error_code" "Default Apache page still showing — custom webpage not deployed"
        info "Replace /var/www/html/index.html with your custom page"
    elif [ -n "$content" ]; then
        pass "Custom webpage is being served (non-default content detected)"
    else
        fail "$error_code" "No content returned from http://192.168.1.80"
    fi
}

# =============================================================================
# Per-VM check suites
# =============================================================================

run_external_gateway() {
    echo -e "\n${BOLD}${CYAN}VM detected: External Gateway${NC}"

    section "Part A — nftables Service"
    check_nft_service "A1"

    section "Part A — NAT Masquerade"
    check_nft_masquerade "A2"

    section "Part A — DNAT Port Forwarding"
    check_nft_dnat_http "A2"
    check_nft_dnat_https "A2"

    section "Part A — Forward Rules"
    check_nft_forward_inbound "A2"
    check_nft_forward_dmz_out "A2"

    section "Part A — Connectivity"
    check_ping "192.168.1.1"  "Internal Gateway (DMZ side)" "A3"
    check_ping "192.168.1.80" "Ubuntu Server"               "A3"
    check_ping "10.10.1.1"   "Ubuntu Desktop"               "A3"

    section "Part A — Internet Access"
    check_internet "A3"

    section "Part A — Web Server Reachable (via DNAT)"
    check_http    "http://192.168.1.80"  "Ubuntu Server HTTP"  "A4"
    check_https_insecure "https://192.168.1.80" "Ubuntu Server HTTPS" "A4"
}

run_internal_gateway() {
    echo -e "\n${BOLD}${CYAN}VM detected: Internal Gateway${NC}"

    section "Part B — BIND9 Service"
    check_bind9_running "B1"
    check_port_listening "53" "BIND9" "B1"

    section "Part B — DNS Forwarding"
    check_external_dns_forwarding "B2"

    section "Part B — Local Zone"
    check_local_zone_resolves "B3"

    section "Part B — Reverse Lookup"
    check_reverse_lookup "B3"

    section "Part B — DNSSEC"
    check_dnssec_validation "B4"
    check_dnssec_ad_flag "B4"

    section "Part D — Squid Service"
    check_service_active "squid" "D1"
    check_squid_port "D1"

    section "Part D — Squid ACLs"
    check_squid_acl_internal    "D2"
    check_squid_acl_australian  "D2"
    check_squid_acl_office_hours "D2"

    section "Part D — Squid Rules"
    check_squid_deny_australian "D2"
    check_squid_allow_internal  "D2"
    check_squid_rule_order      "D2"

    section "Connectivity"
    check_ping "192.168.1.254" "External Gateway" "GEN"
    check_ping "192.168.1.80"  "Ubuntu Server"    "GEN"
    check_ping "10.10.1.1"    "Ubuntu Desktop"    "GEN"
    check_internet "GEN"
}

run_ubuntu_server() {
    echo -e "\n${BOLD}${CYAN}VM detected: Ubuntu Server${NC}"

    section "Part C — Apache Service"
    check_service_active "apache2" "C1"
    check_port_listening "80"  "Apache HTTP"  "C1"
    check_port_listening "443" "Apache HTTPS" "C1"

    section "Part C — Apache Modules"
    check_apache_modules "C2"

    section "Part C — SSL Configuration"
    check_ssl_cert_exists  "C2"
    check_ssl_params_conf  "C2"
    check_ssl_vhost_conf   "C2"

    section "Part C — Web Server Response"
    check_http           "http://192.168.1.80"  "Apache HTTP"  "C3"
    check_https_insecure "https://192.168.1.80" "Apache HTTPS" "C3"

    section "Part C — Custom Webpage"
    check_custom_webpage "C4"

    section "Connectivity"
    check_ping "192.168.1.254" "External Gateway"            "GEN"
    check_ping "192.168.1.1"   "Internal Gateway (DMZ side)" "GEN"
    check_internet "GEN"
}

run_ubuntu_desktop() {
    echo -e "\n${BOLD}${CYAN}VM detected: Ubuntu Desktop${NC}"

    section "Part B — DNS Resolution via Internal Gateway"
    local zone_result
    zone_result=$(dig @10.10.1.254 +time=5 +tries=1 2>/dev/null)
    if dig @10.10.1.254 google.com +short +time=5 +tries=1 2>/dev/null | grep -qE '^[0-9]'; then
        pass "DNS via 10.10.1.254 resolves external domains"
    else
        fail "B2" "Cannot resolve external domains via DNS at 10.10.1.254"
    fi

    section "Part C — Web Server Access"
    check_http           "http://192.168.1.80"  "Ubuntu Server HTTP (direct)"  "C3"
    check_https_insecure "https://192.168.1.80" "Ubuntu Server HTTPS (direct)" "C3"

    section "Part D — Squid Proxy Reachability"
    if nc -z -w 3 10.10.1.254 8080 2>/dev/null; then
        pass "Squid proxy reachable at 10.10.1.254:8080"
    else
        fail "D1" "Cannot reach Squid proxy at 10.10.1.254:8080"
    fi

    section "Part D — Web Access via Proxy"
    local proxy_code
    proxy_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
        --proxy "http://10.10.1.254:8080" "http://192.168.1.80" 2>/dev/null)
    if [[ "$proxy_code" =~ ^[23] ]]; then
        pass "HTTP $proxy_code — http://192.168.1.80 loads via Squid proxy"
    else
        fail "D3" "http://192.168.1.80 did not load via proxy (HTTP code: ${proxy_code:-no response})"
        info "Ensure Firefox proxy is set to 10.10.1.254:8080 and Squid ACLs allow internal_network"
    fi

    section "Connectivity"
    check_ping "10.10.1.254" "Internal Gateway" "GEN"
    check_ping "192.168.1.80" "Ubuntu Server"   "GEN"
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
        echo -e "  ${GREEN}${BOLD}All checks passed! Activity 2 configuration looks correct.${NC}"
        echo ""
    fi
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Activity 2 Automarker — NAT, DNS, SSL & Proxy${NC}"
echo -e "${BOLD} 3821ICT | Griffith University${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

VM=$(detect_vm)

case "$VM" in
    external_gateway)  run_external_gateway ;;
    internal_gateway)  run_internal_gateway ;;
    ubuntu_server)     run_ubuntu_server ;;
    ubuntu_desktop)    run_ubuntu_desktop ;;
    *)
        echo ""
        echo -e "${RED}[ERROR]${NC} Could not detect which VM this is."
        echo ""
        echo "        Expected IP addresses:"
        echo "          External Gateway  — eth1 at 192.168.1.254"
        echo "          Internal Gateway  — eth0 at 192.168.1.1 AND eth1 at 10.10.1.254"
        echo "          Ubuntu Server     — eth0 at 192.168.1.80"
        echo "          Ubuntu Desktop    — eth0 at 10.10.1.1"
        echo ""
        echo "        Your current addresses:"
        ip -brief addr show 2>/dev/null | sed 's/^/          /'
        echo ""
        exit 1
        ;;
esac

print_summary
