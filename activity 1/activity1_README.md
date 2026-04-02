# Activity 1 — DMZ Networks

> Automarker for Activity 1: DMZ Networks  
> **7015ICT Cyber Security Operation Centres** · Griffith University

← [Back to all activities](../README.md)

---

## Network topology

```
  [ Internet ]
       │
   ┌───┴──────────────────┐
   │    External Gateway   │  eth0 = DHCP (internet)
   │                       │  eth1 = 192.168.1.254/24
   └───┬──────────────────┘
       │  DMZ Network (192.168.1.0/24)
   ┌───┴──────────────────┐       ┌──────────────────────┐
   │   Internal Gateway    │       │    Ubuntu Server      │
   │   eth0 = 192.168.1.1  │       │  eth0 = 192.168.1.80  │
   │   eth1 = 10.10.1.254  │       │   (DMZ web server)    │
   └───┬──────────────────┘       └──────────────────────┘
       │  Internal Network (10.10.1.0/24)
   ┌───┴──────────────────┐
   │    Ubuntu Desktop     │
   │   eth0 = 10.10.1.1    │
   └──────────────────────┘
```

---

## Usage

Run this on **any** of the four VMs after completing the activity. The script will detect which machine it is on automatically.

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/griffith-assessment-automarker/main/activity1/automark_activity1.sh | sudo bash
```

Or download and inspect first:

```bash
wget https://raw.githubusercontent.com/rishonmathew/griffith-assessment-automarker/main/activity1/automark_activity1.sh
chmod +x automark_activity1.sh
sudo ./automark_activity1.sh
```

> **Note:** The External Gateway can always download this script (direct DHCP internet on eth0). The other three VMs can download once NAT and routing are correctly configured — which is the expected run-when-done workflow.

---

## What it checks

| Check | External GW | Internal GW | Ubuntu Server | Ubuntu Desktop |
|---|:---:|:---:|:---:|:---:|
| Interface existence | ✓ | ✓ | ✓ | ✓ |
| IP addressing | ✓ | ✓ | ✓ | ✓ |
| Default / static routes | ✓ | ✓ | ✓ | ✓ |
| IP forwarding enabled | ✓ | ✓ | — | — |
| nftables service running | ✓ | — | — | — |
| nftables forward rules (exact) | ✓ | — | — | — |
| nftables NAT masquerade (exact) | ✓ | — | — | — |
| Ping all reachable VMs | ✓ | ✓ | ✓ | ✓ |
| Internet access (HTTPS) | ✓ | ✓ | ✓ | ✓ |
| Web server HTTP response | — | — | optional | optional |

---

## Error codes

| Code | Meaning |
|---|---|
| E1 | IP address not configured / wrong address |
| E2 | Network interface missing (check Hyper-V adapter assignment) |
| E3 | IP forwarding not enabled or default route missing |
| E4 | nftables rules missing or applied to wrong interface |
| E5 | Cannot ping another VM |
| E6 | No internet access |
| E7 | nftables service not running |
| E8 | Web server not reachable via HTTP |

Full resolution steps for each code are printed inline when a failure is detected.
