# Activity 4.2 — Virtual Private Network (OpenVPN)

> Deploy an OpenVPN server on the internal gateway and generate a working client profile.

## What this activity covers
Installing and configuring OpenVPN, building the CA/PKI vars, and producing a single bundled `.ovpn` client profile. The automarker confirms the server configuration, certificate setup, and client config generation.

## Files
| File | Purpose |
|---|---|
| `automark_activity4.2.sh` | Pass/fail checker for the VPN setup |
| `make_config.sh` | Bundles certs/keys into a single `.ovpn` profile |
| `vars` | Easy-RSA PKI variables |
| `client1.ovpn` | Example generated client profile |
| `docs/` | Activity 4.2 brief |

## Run it
```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity4.2/automark_activity4.2.sh | sudo bash
```

## Documents
- [Activity 4.2 brief — VPN](docs/Activity4-2_VPN.pdf)

## Demo
▶️ [Watch on YouTube](https://youtu.be/9rf-OxM6hog)
