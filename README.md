# wsl2-wifi-monitor-mode

> Enable WiFi monitor mode for RTL8812BU / RTL8822BU USB adapters inside Kali Linux on WSL2 — no custom kernel build required.

Tested with: **TP-Link Archer T3U** (VID:PID `2357:0138`) · **Kali Linux WSL2** · **Windows 10/11**

---

## How It Works

WSL2 cannot access USB devices natively, and the RTL8822BU driver is not included in the Microsoft WSL2 kernel. This toolset solves both problems with three scripts:

| Script | Platform | What it does |
|---|---|---|
| `attach.ps1` | Windows PowerShell | Installs usbipd-win, binds and attaches the USB adapter to WSL2 by auto-detecting VID:PID |
| `setup.sh` | Kali WSL2 (bash) | Downloads matching WSL2 kernel source, generates config headers from `/proc/config.gz`, patches the Makefile, and compiles the 88x2bu out-of-tree driver |
| `monitor.sh` | Kali WSL2 (bash) | Force-loads the compiled driver module and sets `wlan0` to monitor mode |

The result: a fully working `wlan0` interface in monitor mode inside Kali WSL2, capturing real 802.11 frames with radiotap headers.

---

## Requirements

**Windows side**
- Windows 10 (21H2+) or Windows 11
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) available
- PowerShell running as Administrator
- RTL8812BU / RTL8822BU USB WiFi adapter plugged in (e.g. TP-Link Archer T3U)

**WSL2 side**
- Kali Linux installed from the Microsoft Store
- Run all WSL scripts as root (`sudo bash` or `sudo -i`)

---

## Usage

### Step 1 — Attach the USB adapter to WSL2 (Windows, run as Admin)

```powershell
# Default VID:PID is 2357:0138 (TP-Link Archer T3U)
powershell -ExecutionPolicy Bypass -File .\wsl2-wifi-monitor\attach.ps1

# Custom adapter
powershell -ExecutionPolicy Bypass -File .\wsl2-wifi-monitor\attach.ps1 -VidPid "XXXX:YYYY"

# Custom distro
powershell -ExecutionPolicy Bypass -File .\wsl2-wifi-monitor\attach.ps1 -Distro "Ubuntu"
```

`attach.ps1` will:
1. Install `usbipd-win` via winget if not already present
2. Auto-detect the adapter's USB bus ID from VID:PID
3. Bind the device (requires elevation, handled automatically)
4. Start the WSL distro and attach the USB device to it

---

### Step 2 — Compile the driver (Kali WSL2, run as root)

```bash
sudo bash wsl2-wifi-monitor/setup.sh
```

`setup.sh` will:
1. Install build dependencies (`build-essential`, `flex`, `bison`, `libssl-dev`, `libelf-dev`, `bc`, `dwarves`, `git`, `iw`, etc.)
2. Detect your running WSL2 kernel version and find the matching tag on Microsoft's GitHub
3. Sparse-checkout only the required kernel source subdirectories (`scripts`, `include`, `arch`, `tools`)
4. Generate `autoconf.h` and `auto.conf` directly from `/proc/config.gz` using Python — bypassing a full kernel build
5. Patch the Makefile for dash/bash compatibility
6. Clone [morrownr/88x2bu-20210702](https://github.com/morrownr/88x2bu-20210702) and compile the driver against your live kernel

> **Note:** First run takes several minutes due to kernel source checkout and compilation.

---

### Step 3 — Enable monitor mode (Kali WSL2, run as root)

```bash
sudo bash wsl2-wifi-monitor/monitor.sh
```

`monitor.sh` will:
1. Check the compiled `.ko` exists at `/opt/88x2bu/88x2bu.ko`
2. Force-load it with `insmod`
3. Bring `wlan0` down, switch it to monitor mode with `iw`, and bring it back up
4. Print interface info confirming monitor mode is active

---

## Capturing Packets

Once `wlan0` is in monitor mode:

```bash
# Scan all channels for nearby networks
airodump-ng wlan0

# Capture to file
airodump-ng wlan0 -w capture

# Raw packet capture with tcpdump
tcpdump -i wlan0 -w capture.pcap

# Scan 2.4 GHz + 5 GHz bands
airodump-ng --band abg wlan0
```

---

## Troubleshooting

**Device not found by attach.ps1**
- Make sure the adapter is plugged in before running the script
- Verify the VID:PID with `usbipd list` in PowerShell
- Pass the correct `-VidPid` parameter

**Kernel tag not found during setup.sh**
- Your WSL2 kernel may be newer than the latest tagged release
- Run `uname -r` in WSL2 and check available tags at [microsoft/WSL2-Linux-Kernel/tags](https://github.com/microsoft/WSL2-Linux-Kernel/tags)

**wlan0 not found after attach**
- Wait a few seconds after attaching; the interface takes a moment to appear
- Confirm the adapter is attached: run `usbipd list` in PowerShell and look for `Attached`
- Re-run `monitor.sh` after confirming the interface is visible with `ip link`

**insmod: force flag may indicate kernel mismatch**
- This is expected — the driver is loaded with `--force` because the kernel modules directory may not perfectly align
- If `wlan0` comes up in monitor mode, the driver is working correctly

---

## Files

```
wsl2-wifi-monitor/
├── attach.ps1   # Windows: USB passthrough via usbipd-win
├── setup.sh     # Kali WSL2: driver build pipeline
└── monitor.sh   # Kali WSL2: load driver + enable monitor mode
```

---

## Credits

- Driver source: [morrownr/88x2bu-20210702](https://github.com/morrownr/88x2bu-20210702)
- USB passthrough: [dorssel/usbipd-win](https://github.com/dorssel/usbipd-win)
- Kernel source: [microsoft/WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel)

---

## License

MIT — see [LICENSE](LICENSE)
