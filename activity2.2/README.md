# Activity 2.2 — DNS Server (BIND9)

> Configure an authoritative DNS server with BIND9, including forward and reverse zones.

## What this activity covers
The second task of the "Secure Web" activity: deploying BIND9 with a forward zone for the domain and a reverse zone for the `192.168.1` subnet. The automarker validates the named configuration, both zone files, and resolution behaviour.

## Files
| File | Purpose |
|---|---|
| `automark_activity2.2.sh` | Pass/fail checker for the DNS configuration |
| `setup_dns.sh` | Top-level DNS provisioning helper |
| `bind/setup-bind.sh` | Installs and configures BIND9 |
| `bind/named.conf.*` | named options, local zones, and append config |
| `bind/db.YOURDOMAIN.com` | Forward zone template |
| `bind/db.192.168.1` | Reverse zone template |
| `docs/` | Activity 2 brief |

## Run it
```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity2.2/automark_activity2.2.sh | sudo bash
```

## Documents
- [Activity 2.2 brief — DNS](docs/NA21_Activity2.2_DNS.pdf)

## Demo
▶️ [Watch on YouTube](https://youtu.be/REPLACE_ACTIVITY2-2_DNS)
