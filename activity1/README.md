# Activity 1 — DMZ Network

> Build and segment a virtual network with a DMZ on a Hyper-V lab environment, then validate the firewall configuration on the external gateway.

## What this activity covers
A virtual network is constructed and extended from the Week 1 baseline, placing internet-facing services in a DMZ that is isolated from the internal network by an external gateway. The automarker verifies the expected `nftables` ruleset on the gateway (matched by interface pair, not by keyword) and confirms the DMZ segmentation is correct.

## Files
| File | Purpose |
|---|---|
| `automark_activity1.sh` | Auto-detecting pass/fail checker for the DMZ + gateway config |
| `external-gateway-nftables.conf` | Reference nftables ruleset for the external gateway |
| `docs/` | Activity brief |

## Run it
```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity1/automark_activity1.sh | sudo bash
```

## Documents
- [Activity 1 brief — DMZ Network](docs/NA21_Activity1DMZNetworks.pdf)

## Demo
▶️ [Watch on YouTube](https://youtu.be/REPLACE_ACTIVITY1_DMZ](https://www.youtube.com/watch?v=SQG-12Ahlw0))
