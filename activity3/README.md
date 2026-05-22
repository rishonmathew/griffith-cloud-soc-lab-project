# Activity 3 — Email Server

> Build a full mail stack — Postfix (SMTP) and Dovecot (IMAP) on Ubuntu Server, with Thunderbird as the client — behind an nftables firewall.

## What this activity covers
A working email server/client setup: Postfix handles outbound/relay, Dovecot serves mailboxes, virtual mailbox mapping is configured, and nftables is opened for the relevant mail ports. The automarker checks each service template and the firewall rules.

## Files
| File | Purpose |
|---|---|
| `automark_activity3.sh` | Pass/fail checker for the mail stack |
| `postfix/setup-postfix.sh`, `main.cf.template`, `virtual.template` | Postfix SMTP setup |
| `dovecot/setup-dovecot.sh`, `10-master.conf.template` | Dovecot IMAP setup |
| `nftables/setup-nftables-smtp.sh`, `nftables.conf` | Mail firewall rules |
| `docs/` | Activity 3 brief |

## Run it
```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity3/automark_activity3.sh | sudo bash
```

## Documents
- [Activity 3 brief — Mail Server](docs/NA21_Activity3_Mail_Server.pdf)

## Demo
▶️ [Watch on YouTube](https://youtu.be/REPLACE_ACTIVITY3_MAILSERVER)
