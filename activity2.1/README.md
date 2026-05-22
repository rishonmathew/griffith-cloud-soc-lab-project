# Activity 2.1 — Secure Web Server (SSL/TLS)

> Stand up an Apache web server that serves pages over an encrypted SSL/TLS channel.

## What this activity covers
The first task of the "Secure Web" activity: configuring HTTPS on the web server with hardened SSL parameters. The automarker checks the SSL virtual host, the TLS parameters, and that the firewall permits the expected traffic.

## Files
| File | Purpose |
|---|---|
| `automark_activity2.1.sh` | Pass/fail checker for the SSL/TLS web server |
| `setup_ssl.sh` | Helper that provisions the SSL site |
| `default-ssl.conf` | Apache SSL virtual host |
| `ssl-params.conf` | Hardened TLS parameters |
| `nftables.conf` | Firewall ruleset for the web server |
| `docs/` | Activity 2 brief |

## Run it
```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity2.1/automark_activity2.1.sh | sudo bash
```

## Documents
- [Activity 2.1 brief — Secure Web](docs/NA21_Activity2.1_SecureWeb.pdf)

## Demo
▶️ [Watch on YouTube](https://youtu.be/EsB6C9z67kw)
