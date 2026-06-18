#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root"
    exit 1
fi

KERNEL=$(uname -r)
KERNEL_BASE="${KERNEL%%-*}"
KERNEL_TAG="linux-msft-wsl-${KERNEL_BASE}"
KERNEL_SRC="/usr/src/wsl-kernel"
DRIVER_DIR="/opt/88x2bu"

echo "[*] Kernel: ${KERNEL}"
echo "[*] Tag: ${KERNEL_TAG}"

apt-get update -qq
apt-get install -y build-essential flex bison libssl-dev libelf-dev bc dwarves git libncurses-dev python3 iw

if ! git ls-remote --tags https://github.com/microsoft/WSL2-Linux-Kernel.git "refs/tags/${KERNEL_TAG}" 2>/dev/null | grep -q "${KERNEL_TAG}"; then
    echo "[-] Kernel tag ${KERNEL_TAG} not found on GitHub"
    exit 1
fi

if [ ! -d "${KERNEL_SRC}" ]; then
    echo "[*] Cloning WSL2 kernel source..."
    git clone --branch "${KERNEL_TAG}" \
        https://github.com/microsoft/WSL2-Linux-Kernel.git \
        "${KERNEL_SRC}"
fi

cd "${KERNEL_SRC}"

cp /proc/config.gz .
gunzip -f config.gz
cp config .config

mkdir -p include/config include/generated

echo "[*] Preparing kernel..."
make ARCH=x86_64 SHELL=/bin/bash -j"$(nproc)" prepare scripts

echo "[*] Running modules_prepare..."
make ARCH=x86_64 SHELL=/bin/bash -j"$(nproc)" modules_prepare

ln -sf "${KERNEL_SRC}" /lib/modules/"${KERNEL}"/build

if [ ! -d "${DRIVER_DIR}" ]; then
    echo "[*] Cloning 88x2bu driver..."
    git clone --depth=1 https://github.com/morrownr/88x2bu-20210702.git "${DRIVER_DIR}"
fi

cd "${DRIVER_DIR}"
echo "[*] Compiling driver..."
make ARCH=x86_64 KSRC="${KERNEL_SRC}" KBUILD_MODPOST_WARN=1 -j"$(nproc)"

echo ""
echo "[+] Done. Run monitor.sh to enable monitor mode."
