# WSL2 WiFi Monitor Mode

Enables monitor mode for RTL8812BU / RTL8822BU USB WiFi adapters inside Kali Linux WSL2 on Windows.

Tested with TP-Link Archer T3U on Windows 11 with Kali Linux WSL2.

## Requirements

- Windows 10/11
- Kali Linux (or Ubuntu/Debian) installed in WSL2
- RTL8812BU or RTL8822BU based USB WiFi adapter
- Admin access on Windows

## Supported Adapters

Any adapter using RTL8812BU or RTL8822BU chipset. Common ones:

- TP-Link Archer T3U
- TP-Link Archer T3U Plus
- TP-Link Archer T4U v3

## Setup (run once)

**Step 1 — Windows (run as Administrator):**
```powershell
.\attach.ps1
```

**Step 2 — Kali WSL (run as root):**
```bash
bash setup.sh
```

This takes 15–20 minutes. It downloads the kernel source and compiles the driver.

## Every session after

**Windows (Administrator):**
```powershell
.\attach.ps1
```

**Kali WSL (root):**
```bash
bash monitor.sh
```

## Using a different adapter

Pass the VID:PID of your adapter to attach.ps1:
```powershell
.\attach.ps1 -VidPid "0bda:8812"
```

To find your adapter's VID:PID on Windows:
```powershell
usbipd list
```

## After monitor mode is enabled

```bash
airodump-ng wlan0
tcpdump -i wlan0 -w capture.pcap
airodump-ng --band abg wlan0
```
