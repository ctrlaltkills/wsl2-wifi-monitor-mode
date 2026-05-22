#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root"
    exit 1
fi

DRIVER_KO="/opt/88x2bu/88x2bu.ko"
INTERFACE="wlan0"

if [ ! -f "${DRIVER_KO}" ]; then
    echo "[-] Driver not found at ${DRIVER_KO} — run setup.sh first"
    exit 1
fi

if ! lsmod | grep -q 88x2bu; then
    echo "[*] Loading driver..."
    insmod --force "${DRIVER_KO}"
    sleep 2
fi

if ! ip link show "${INTERFACE}" &>/dev/null; then
    echo "[-] ${INTERFACE} not found — is the USB adapter attached?"
    echo "    Windows: usbipd attach --wsl --busid <ID>"
    exit 1
fi

echo "[*] Enabling monitor mode..."
ip link set "${INTERFACE}" down
iw dev "${INTERFACE}" set type monitor
ip link set "${INTERFACE}" up
sleep 1

iw dev "${INTERFACE}" info
echo ""
echo "[+] ${INTERFACE} is in monitor mode"
echo ""
echo "Usage:"
echo "  airodump-ng ${INTERFACE}"
echo "  tcpdump -i ${INTERFACE} -w capture.pcap"
echo "  airodump-ng --band abg ${INTERFACE}"
