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
    git clone --depth=1 --filter=blob:none --no-checkout \
        --branch "${KERNEL_TAG}" \
        https://github.com/microsoft/WSL2-Linux-Kernel.git \
        "${KERNEL_SRC}"
fi

cd "${KERNEL_SRC}"

git sparse-checkout init
git sparse-checkout set scripts include arch tools
git checkout

cp /proc/config.gz .
gunzip -f config.gz
cp config .config

mkdir -p include/config include/generated

python3 - << 'PYEOF'
import re

lines = open('.config').read().splitlines()
autoconf = ['/* Automatically generated. */', '#ifndef __GENERATED_AUTOCONF_H', '#define __GENERATED_AUTOCONF_H', '']
auto_conf = []

for line in lines:
    m = re.match(r'^(CONFIG_\w+)=(.*)$', line)
    if not m:
        continue
    key, val = m.group(1), m.group(2)
    auto_conf.append(f'{key}={val}')
    if val == 'y':
        autoconf.append(f'#define {key} 1')
    elif val == 'm':
        autoconf.append(f'#define {key}_MODULE 1')
    elif val != 'n':
        autoconf.append(f'#define {key} {val}')

autoconf += ['', '#endif']
open('include/generated/autoconf.h', 'w').write('\n'.join(autoconf) + '\n')
open('include/config/auto.conf', 'w').write('\n'.join(auto_conf) + '\n')
open('include/config/auto.conf.cmd', 'w').write('include/config/auto.conf: \\\n')
PYEOF

bash scripts/mkcompile_h x86_64 "gcc" ld > include/generated/compile.h 2>/dev/null || echo "" > include/generated/compile.h

python3 - << 'PYEOF'
content = open('Makefile').read()

content = content.replace(
    'include/generated/compile.h: FORCE',
    'include/generated/compile.h:',
    1
)

start = content.find('prepare: CC_VERSION_TEXT :=')
end = content.find('\nPHONY += help', start)
if start != -1 and end != -1:
    new_block = 'prepare: CC_VERSION_TEXT := $(CC_VERSION_TEXT)\nprepare:\n\t@:'
    content = content[:start] + new_block + '\n' + content[end:]

open('Makefile', 'w').write(content)
print('[*] Makefile patched')
PYEOF

echo "[*] Building kernel scripts..."
make ARCH=x86_64 -j"$(nproc)" scripts

echo "[*] Running modules_prepare..."
make ARCH=x86_64 -j"$(nproc)" modules_prepare

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
