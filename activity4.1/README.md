# Activity 4.1 — Firewalls

> Configure a stateful firewall on the external gateway with default-drop policies and explicit allow rules.

## What this activity covers
Setting up firewall policies on the external gateway: default DROP on INPUT/OUTPUT/FORWARD chains, then permitting only the required traffic. The automarker verifies the nftables ruleset matches the expected policy and per-interface rules.

## Files
| File | Purpose |
|---|---|
| `automark_activity4.1.sh` | Pass/fail checker for the firewall policy |
| `nftables.conf` | Reference firewall ruleset |
| `docs/` | Activity 4.1 brief |

## Run it
```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity4.1/automark_activity4.1.sh | sudo bash
```

## Documents
- [Activity 4.1 brief — Firewalls / nftables](docs/Activity4-1_Firewalls_nftables.pdf)

## Demo
▶️ [Watch on YouTube](https://youtu.be/IfUIZxea2NQ)
