#!/bin/bash
# =============================================================================
# Activity 3 - Dovecot Setup Script (Ubuntu Server)
# Downloads Dovecot config templates from GitHub, applies them, and
# walks students through entering the 10-master.conf socket values
# so they understand what each setting does.
# =============================================================================

exec </dev/tty

REPO="https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity3/dovecot"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Activity 3 — Dovecot Config Setup${NC}"
echo -e "${BOLD} 7015ICT | Griffith University${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Run this script with sudo: sudo bash setup-dovecot.sh"
    exit 1
fi

download_template() {
    local name=$1 url=$2 dest=$3
    if ! curl -fsSL "$url" -o "$dest" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Could not download $name from GitHub."
        echo "        URL: $url"
        echo "        Check your internet connection."
        exit 1
    fi
    echo -e "  ${GREEN}[DONE]${NC} $name downloaded"
}

# =============================================================================
# Step 1 — Install Dovecot packages
# =============================================================================
echo -e "${CYAN}[1/6]${NC} Checking Dovecot installation..."

PACKAGES="dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd"
MISSING=""
for pkg in $PACKAGES; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    echo -e "  ${YELLOW}[INFO]${NC} Installing missing packages:$MISSING"
    apt-get update -q
    apt-get install -y -q $MISSING
else
    echo -e "  ${GREEN}[DONE]${NC} All Dovecot packages already installed"
fi
echo ""

# =============================================================================
# Step 2 — Apply fixed config files
# =============================================================================
echo -e "${CYAN}[2/6]${NC} Applying fixed config files..."
echo ""
echo "  These files have fixed values for this lab — applied directly:"
echo ""
echo "    dovecot.conf     → protocols = imap pop3 lmtp"
echo "    10-mail.conf     → mail_location = maildir:~/Maildir"
echo "    10-auth.conf     → disable_plaintext_auth = no, auth_username_format = %Ln"
echo "    10-ssl.conf      → ssl = no"
echo "    20-lmtp.conf     → auth_username_format = %Ln  (LMTP delivery fix)"
echo ""

TMP=$(mktemp -d)
download_template "10-master.template" "$REPO/10-master.conf.template" "$TMP/10-master.template"
echo ""

# dovecot.conf
if grep -q "^protocols" /etc/dovecot/dovecot.conf 2>/dev/null; then
    sed -i 's/^protocols.*/protocols = imap pop3 lmtp/' /etc/dovecot/dovecot.conf
else
    echo "protocols = imap pop3 lmtp" >> /etc/dovecot/dovecot.conf
fi
echo -e "  ${GREEN}[DONE]${NC} dovecot.conf"

# 10-mail.conf
sed -i 's|^#*\s*mail_location\s*=.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
sed -i 's|^#*\s*mail_privileged_group\s*=.*|mail_privileged_group = mail|' /etc/dovecot/conf.d/10-mail.conf
echo -e "  ${GREEN}[DONE]${NC} 10-mail.conf"

# 10-auth.conf
sed -i 's|^#*\s*disable_plaintext_auth\s*=.*|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|^#*\s*auth_mechanisms\s*=.*|auth_mechanisms = plain login|' /etc/dovecot/conf.d/10-auth.conf
if grep -q "^auth_username_format" /etc/dovecot/conf.d/10-auth.conf; then
    sed -i 's|^auth_username_format.*|auth_username_format = %Ln|' /etc/dovecot/conf.d/10-auth.conf
else
    echo "auth_username_format = %Ln" >> /etc/dovecot/conf.d/10-auth.conf
fi
echo -e "  ${GREEN}[DONE]${NC} 10-auth.conf (includes auth_username_format = %Ln)"

# 10-ssl.conf
sed -i 's|^#*\s*ssl\s*=.*|ssl = no|' /etc/dovecot/conf.d/10-ssl.conf
echo -e "  ${GREEN}[DONE]${NC} 10-ssl.conf"

# 20-lmtp.conf — KEY FIX: strips @domain from LMTP recipient so Dovecot
# finds local user 'user1' instead of failing on 'user1@example7015ict.com'
cat > /etc/dovecot/conf.d/20-lmtp.conf << 'EOF'
# =============================================================================
# 20-lmtp.conf — Activity 3 — Griffith University
# =============================================================================
# auth_username_format = %Ln strips the @domain from the LMTP recipient.
#
# Without this: Postfix sends 'user1@example.com' via LMTP
#               Dovecot looks for system user 'user1@example.com' → 550 not found
#
# With this:    Dovecot strips domain → looks for 'user1' → delivered ✓
# =============================================================================
protocol lmtp {
  postmaster_address = postmaster@localhost
  auth_username_format = %Ln
}
EOF
echo -e "  ${GREEN}[DONE]${NC} 20-lmtp.conf (LMTP domain-strip fix)"
echo ""

# =============================================================================
# Step 3 — Interactive 10-master.conf setup
# =============================================================================
echo -e "${CYAN}[3/6]${NC} Configure 10-master.conf — Socket Settings"
echo ""
echo "  These sockets allow Postfix and Dovecot to communicate."
echo "  Without them, mail delivery will not work."
echo ""
echo -e "  ${YELLOW}Press Enter to accept the default shown in [brackets].${NC}"
echo ""

echo -e "  ${BOLD}IMAP listener port${NC}"
echo "  Standard IMAP port — Thunderbird connects here."
read -rp "  Enter IMAP port [143]: " IMAP_PORT
IMAP_PORT=${IMAP_PORT:-143}
echo ""

echo -e "  ${BOLD}LMTP socket mode${NC}"
echo "  How Postfix hands mail to Dovecot for local delivery."
echo "  0600 = only the owner can read/write (keeps socket private to postfix)."
read -rp "  Enter LMTP socket mode [0600]: " LMTP_MODE
LMTP_MODE=${LMTP_MODE:-0600}
echo ""

echo -e "  ${BOLD}LMTP socket user${NC}"
echo "  Must be owned by postfix so Postfix can connect."
read -rp "  Enter LMTP socket user [postfix]: " LMTP_USER
LMTP_USER=${LMTP_USER:-postfix}
echo ""

echo -e "  ${BOLD}LMTP socket group${NC}"
echo "  Same reason — Postfix needs group access too."
read -rp "  Enter LMTP socket group [postfix]: " LMTP_GROUP
LMTP_GROUP=${LMTP_GROUP:-postfix}
echo ""

echo -e "  ${BOLD}Auth socket mode${NC}"
echo "  Postfix verifies user passwords through this socket."
echo "  0666 = both postfix and dovecot can connect (wider than LMTP)."
read -rp "  Enter auth socket mode [0666]: " AUTH_MODE
AUTH_MODE=${AUTH_MODE:-0666}
echo ""

echo -e "  ${BOLD}Auth socket user${NC}"
echo "  postfix must own this socket for credential verification."
read -rp "  Enter auth socket user [postfix]: " AUTH_USER
AUTH_USER=${AUTH_USER:-postfix}
echo ""

echo -e "  ${BOLD}Auth socket group${NC}"
read -rp "  Enter auth socket group [postfix]: " AUTH_GROUP
AUTH_GROUP=${AUTH_GROUP:-postfix}
echo ""

echo -e "  ${BOLD}auth-userdb socket mode${NC}"
echo "  Internal Dovecot socket — not used by Postfix."
echo "  0600 = locked down to Dovecot only."
read -rp "  Enter auth-userdb mode [0600]: " USERDB_MODE
USERDB_MODE=${USERDB_MODE:-0600}
echo ""

echo -e "  ${BOLD}auth-userdb socket user${NC}"
echo "  Owned by dovecot (not postfix) — internal Dovecot use only."
read -rp "  Enter auth-userdb user [dovecot]: " USERDB_USER
USERDB_USER=${USERDB_USER:-dovecot}
echo ""

# =============================================================================
# Step 4 — Build, preview, confirm, write 10-master.conf
# =============================================================================
echo -e "${CYAN}[4/6]${NC} Building 10-master.conf with your values..."
echo ""

MASTER_CONF=$(sed \
    -e "s/IMAP_PORT/$IMAP_PORT/g" \
    -e "s/LMTP_MODE/$LMTP_MODE/g" \
    -e "s/LMTP_USER/$LMTP_USER/g" \
    -e "s/LMTP_GROUP/$LMTP_GROUP/g" \
    -e "s/AUTH_MODE/$AUTH_MODE/g" \
    -e "s/AUTH_USER/$AUTH_USER/g" \
    -e "s/AUTH_GROUP/$AUTH_GROUP/g" \
    -e "s/USERDB_MODE/$USERDB_MODE/g" \
    -e "s/USERDB_USER/$USERDB_USER/g" \
    "$TMP/10-master.template")

echo -e "  ${BOLD}--- 10-master.conf additions preview ---${NC}"
echo "$MASTER_CONF" | sed 's/^/  /'
echo ""

read -rp "  Do these values look correct? (yes/no): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
    echo -e "${YELLOW}[CANCELLED]${NC} No changes written. Re-run to try again."
    rm -rf "$TMP"
    exit 0
fi
echo ""

cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.backup
echo "" >> /etc/dovecot/conf.d/10-master.conf
echo "# --- Activity 3 additions below ---" >> /etc/dovecot/conf.d/10-master.conf
echo "$MASTER_CONF" >> /etc/dovecot/conf.d/10-master.conf
echo -e "  ${GREEN}[DONE]${NC} 10-master.conf updated (backup: 10-master.conf.backup)"
echo ""

rm -rf "$TMP"

# =============================================================================
# Step 5 — Create Maildir directories
# =============================================================================
echo -e "${CYAN}[5/6]${NC} Creating Maildir directories..."
echo ""

for USERNAME in user1 user2; do
    if id "$USERNAME" &>/dev/null; then
        sudo -u "$USERNAME" mkdir -p /home/"$USERNAME"/Maildir/{new,cur,tmp} 2>/dev/null || true
        chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/Maildir
        echo -e "  ${GREEN}[DONE]${NC} /home/$USERNAME/Maildir created"
    else
        echo -e "  ${YELLOW}[SKIP]${NC} User $USERNAME not found — create with: sudo adduser $USERNAME"
    fi
done
echo ""

# =============================================================================
# Step 6 — Restart and verify
# =============================================================================
echo -e "${CYAN}[6/6]${NC} Restarting services and verifying..."
echo ""

systemctl restart dovecot
systemctl restart postfix
systemctl enable dovecot

echo -e "  ${BOLD}Service status:${NC}"
systemctl is-active --quiet dovecot \
    && echo -e "  ${GREEN}[PASS]${NC} dovecot is active" \
    || echo -e "  ${RED}[FAIL]${NC} dovecot failed — run: sudo journalctl -u dovecot | tail -20"

systemctl is-active --quiet postfix \
    && echo -e "  ${GREEN}[PASS]${NC} postfix is active" \
    || echo -e "  ${RED}[FAIL]${NC} postfix failed"

echo ""
echo -e "  ${BOLD}Listening ports:${NC}"
for PORT in 25 143 110; do
    ss -tuln 2>/dev/null | grep -q ":$PORT " \
        && echo -e "  ${GREEN}[PASS]${NC} Port $PORT listening" \
        || echo -e "  ${RED}[FAIL]${NC} Port $PORT not listening"
done

echo ""
echo -e "  ${BOLD}Postfix/Dovecot sockets:${NC}"
for SOCK in dovecot-lmtp auth; do
    [ -e "/var/spool/postfix/private/$SOCK" ] \
        && echo -e "  ${GREEN}[PASS]${NC} /var/spool/postfix/private/$SOCK" \
        || echo -e "  ${RED}[FAIL]${NC} Missing: /var/spool/postfix/private/$SOCK"
done

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Dovecot setup complete!${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  NEXT STEPS:"
echo "  1. Ensure users exist:  sudo adduser user1  /  sudo adduser user2"
echo "  2. Test delivery from server:"
echo '       echo "Test" | mail -s "Test" -r server-user@YOURDOMAIN desktop-user@YOURDOMAIN'
echo "  3. Check inbox:  sudo ls -la /home/user1/Maildir/new/"
echo ""
echo "  Thunderbird settings (Ubuntu Desktop):"
echo "    Incoming IMAP: 192.168.1.80 | port 143 | security: None | user: user1"
echo "    Outgoing SMTP: 192.168.1.80 | port 25  | security: None | user: user1"
echo "    Authentication: Password, transmitted insecurely"
echo "    Password: password"
echo ""