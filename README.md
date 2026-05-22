# Griffith Cloud SOC Lab

> Automated configuration-checking scripts for the **7015ICT Cyber Security Operation Centres** lab activities at Griffith University — one self-contained automarker per activity, each with the reference configs, the activity brief, and a demo video.

---

## Overview

This repository is part of a project to **revamp Griffith University's Cyber Security Operation Centres lab for future students**. It contains a complete set of automarking scripts — one per lab activity. Each script runs directly on the student's VM, auto-detects which machine it is on, validates the expected configuration, and reports colour-coded pass/fail results with numbered error codes.

Scripts are designed to be downloaded by students at the end of each activity for self-checking, and can be used by teaching staff as a consistent marking baseline. The goal is to give future cohorts faster feedback, clearer diagnostics, and a more reliable lab experience.

---

## Activities

| Activity | Topic | Script | Brief | Demo | Status |
|---|---|---|---|---|---|
| [Activity 1](activity1) | DMZ Network | `automark_activity1.sh` | [PDF](activity1/docs/NA21_Activity1DMZNetworks.pdf) | [▶️](activity1/README.md#demo) | ✅ |
| [Activity 2.1](activity2.1) | Secure Web (SSL/TLS) | `automark_activity2.1.sh` | [PDF](activity2.1/docs/NA21_Activity2.1_SecureWeb.pdf) | [▶️](activity2.1/README.md#demo) | ✅ |
| [Activity 2.2](activity2.2) | DNS (BIND9) | `automark_activity2.2.sh` | [PDF](activity2.2/docs/NA21_Activity2.2_DNS.pdf) | [▶️](activity2.2/README.md#demo) | ✅ |
| [Activity 3](activity3) | Email Server | `automark_activity3.sh` | [PDF](activity3/docs/NA21_Activity3_Mail_Server.pdf) | [▶️](activity3/README.md#demo) | ✅ |
| [Activity 4.1](activity4.1) | Firewalls | `automark_activity4.1.sh` | [PDF](activity4.1/docs/Activity4-1_Firewalls_nftables.pdf) | [▶️](activity4.1/README.md#demo) | ✅ |
| [Activity 4.2](activity4.2) | VPN (OpenVPN) | `automark_activity4.2.sh` | [PDF](activity4.2/docs/Activity4-2_VPN.pdf) | [▶️](activity4.2/README.md#demo) | ✅ |

---

## Quick start (for students)

Find your activity above, open its folder, and copy the one-liner from its README. Example for Activity 1:

```bash
curl -fsSL https://raw.githubusercontent.com/rishonmathew/griffith-cloud-soc-lab/main/activity1/automark_activity1.sh | sudo bash
```

> Scripts must be run with `sudo`. Each activity folder has its own README with full usage notes.

---

## Repository structure

```
griffith-cloud-soc-lab/
├── README.md                     ← You are here
├── activity1/
│   ├── automark_activity1.sh
│   ├── external-gateway-nftables.conf
│   ├── README.md
│   └── docs/                     ← Activity brief(s)
├── activity2.1/  …  activity4.2/ (same pattern)
```

---

## Design principles

- **Self-contained** — each script works standalone with no dependencies beyond standard Ubuntu tools.
- **Auto-detecting** — scripts identify which VM they are running on from IP addresses, so the same command works on every machine.
- **Non-destructive** — read-only checks only; scripts never modify system configuration.
- **Inline diagnostics** — on failure, relevant live state is printed immediately for self-diagnosis.
- **Exact validation** — checks verify specific expected values, not just keyword presence.

---

## Environment

All scripts target the Hyper-V based lab environment used in **7015ICT** at Griffith University. VMs run Ubuntu Server / Desktop 22.04 LTS on a Windows host with Hyper-V virtual switches.

---

## Licence

MIT — free to use, adapt, and redistribute with attribution.
