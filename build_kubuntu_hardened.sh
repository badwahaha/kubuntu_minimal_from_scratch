#!/usr/bin/env bash
# ==============================================================================
# HARDENED KUBUNTU 26.04 LTS (RESOLUTE) MINIMAL ISO ENGINE FROM SCRATCH
# Fully Corrected Dynamic String Expansion for Cloud Build Actions Platforms
# ==============================================================================

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Pipeline Target Configurations
CODENAME="resolute"
MIRROR="http://archive.ubuntu.com/ubuntu"

BUILD_DIR="/tmp/kubuntu-hardened-build"
ROOTFS="${BUILD_DIR}/chroot"
IMAGE_DIR="${BUILD_DIR}/iso_structure"
ISO_OUT="${GITHUB_WORKSPACE:-/tmp}/kubuntu-26.04-minimal-hardened.iso"

# 2. Advanced Signal Trap Cleanup Handler (Aligned with exact mounts)
cleanup() {
    echo "🚨 Signal caught or process ended. Commencing filesystem safety cleanup..."
    set +e
    for mnt in pts dev proc sys; do
        if mountpoint -q "${ROOTFS}/${mnt}"; then
            sudo umount -l "${ROOTFS}/${mnt}" || sudo umount "${ROOTFS}/${mnt}"
        fi
    done
    echo "🧹 Cleanup sequence finished."
}
trap cleanup EXIT INT TERM

echo "=== [Step 1/8] Environment Setup & Packaging Dependencies ==="
sudo rm -rf "${BUILD_DIR}"
mkdir -p "${ROOTFS}" "${IMAGE_DIR}/casper" "${IMAGE_DIR}/boot/grub"

sudo apt-get update -qq
sudo apt-get install -y -qq debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin binutils gdisk rsync zstd

# 3. Bootstrap OS Engine Tree
echo "=== [Step 2/8] Instantiating Clean Resolute Raccoon Operating System Tree ==="
sudo debootstrap --variant=minbase --components=main,universe,restricted,multiverse \
    "${CODENAME}" "${ROOTFS}" "${MIRROR}" /usr/share/debootstrap/scripts/noble

# 4. Virtual Mount Binding Execution
echo "=== [Step 3/8] Bridging Virtual Host Kernel Filesystem Tables ==="
sudo mount --bind /dev "${ROOTFS}/dev"
sudo mount --bind /dev/pts "${ROOTFS}/dev/pts"
sudo mount --bind /proc "${ROOTFS}/proc"
sudo mount --bind /sys "${ROOTFS}/sys"
sudo cp /etc/resolv.conf "${ROOTFS}/etc/resolv.conf"

# 5. Injected Chroot Construction Module
echo "=== [Step 4/8] Building Target Workspace Core via Layered Environment ==="
cat << EOF | sudo chroot "${ROOTFS}" /bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export MIRROR="${MIRROR}"
export CODENAME="${CODENAME}"

echo "Migrating repository mappings to DEB822 layout structure..."
if [ -f /etc/apt/sources.list ]; then
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
fi

mkdir -p /etc/apt/sources.list.d

# SOURCES is unquoted to allow variable expansion inside the chroot context
cat << SOURCES > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: \$MIRROR
Suites: \$CODENAME
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: \$MIRROR
Suites: \$CODENAME-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: \$MIRROR
Suites: \$CODENAME-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: \$MIRROR
Suites: \$CODENAME-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES

apt-get update -qq
apt-get upgrade -y -qq

# A. Base System Kernel, Compression & Microcode Hardware Layer
apt-get install -y -qq --no-install-recommends \
    linux-generic systemd-sysv initramfs-tools linux-firmware zstd

# B. Live Boot Orchestration Engines (Casper Infrastructure)
apt-get install -y -qq --no-install-recommends \
    casper network-manager netplan.io sudo user-setup

# C. Calamares Installer & Kubuntu Configurations
apt-get install -y -qq --no-install-recommends \
    calamares calamares-settings-kubuntu kubuntu-settings-desktop

# D. Desktop Shell & Requested Core Apps (Konsole, Dolphin, Kate)
apt-get install -y -qq --no-install-recommends \
    kde-plasma-desktop plasma-workspace konsole dolphin kate \
    kio-extras systemsettings xinit xserver-xorg-core xserver-xorg-video-all

# Configure Default Session & Desktop User Controls
echo "kubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kubuntu
chmod 0440 /etc/sudoers.d/kubuntu

# Ensure /var/crash exists so init scripts don't fail
mkdir -p /var/crash
chown root:root /var/crash
chmod 0755 /var/crash

# Set hostname and /etc/hosts to avoid "sudo: unable to resolve host (none)"
echo "kubuntu-live" > /etc/hostname
cat >> /etc/hosts <<HOSTS
127.0.0.1 kubuntu-live localhost
127.0.1.1 kubuntu-live
::1 localhost ip6-localhost ip6-loopback
HOSTS

# Install live and keyboard/console packages noninteractively so postinst scripts succeed
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  live-boot live-config casper \
  console-setup keyboard-configuration console-data \
  sddm

# Create the kubuntu live user and give it passwordless sudo (and a sane home)
groupadd -f netdev || true
useradd -m -s /bin/bash -G sudo,netdev,audio,video kubuntu || true
passwd -d kubuntu || true
echo "kubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kubuntu
chmod 0440 /etc/sudoers.d/kubuntu
mkdir -p /home/kubuntu/.cache /home/kubuntu/.config
chown -R kubuntu:kubuntu /home/kubuntu

# Configure SDDM autologin for KDE Plasma (adjust Session if needed)
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/0-autologin.conf <<SDF
[Autologin]
User=kubuntu
Session=plasma.desktop
SDF

# make sure console setup is noninteractive (optional preseeding)
debconf-set-selections <<DEB
keyboard-configuration  keyboard-configuration/layout  select  English (US)
keyboard-configuration  keyboard-configuration/modelcode  string  pc105
DEB

# ---------------------------------------------------------------------
# Compatibility: ensure canonical "ubuntu" live user + helper stubs exist
# Many upstream live scripts and package postinst hooks expect a user
# named "ubuntu" and a handful of helper scripts. Create them here.
# ---------------------------------------------------------------------
groupadd -f netdev || true
useradd -m -s /bin/bash -G sudo,netdev,audio,video ubuntu || true
passwd -d ubuntu || true
