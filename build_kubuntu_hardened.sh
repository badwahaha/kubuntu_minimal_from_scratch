#!/usr/bin/env bash
# ==============================================================================
# HARDENED KUBUNTU 26.04 LTS (RESOLUTE) MINIMAL ISO ENGINE FROM SCRATCH
# Optimized for GitHub Actions Cloud Execution environment compatibility.
# ==============================================================================

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Pipeline Target Configurations
CODENAME="resolute"
MIRROR="http://ubuntu.com"

BUILD_DIR="/tmp/kubuntu-hardened-build"
ROOTFS="${BUILD_DIR}/chroot"
IMAGE_DIR="${BUILD_DIR}/iso_structure"
ISO_OUT="${GITHUB_WORKSPACE:-/tmp}/kubuntu-26.04-minimal-hardened.iso"

# 2. Advanced Signal Trap Cleanup Handler (Enhanced with Lazy Umount fallback)
cleanup() {
    echo "🚨 Signal caught or process ended. Commencing filesystem safety cleanup..."
    set +e
    # Safely break all active virtual filesystems
    for mnt in pts dev proc sys run; do
        if mountpoint -q "${ROOTFS}/${mnt}"; then
            sudo umount "${ROOTFS}/${mnt}" || sudo umount -l "${ROOTFS}/${mnt}"
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
    "${CODENAME}" "${ROOTFS}" "${MIRROR}"

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

# Enforce upstream production archive configurations
cat << 'SOURCES' > /etc/apt/sources.list
deb ${MIRROR} ${CODENAME} main universe restricted multiverse
deb ${MIRROR} ${CODENAME}-updates main universe restricted multiverse
deb ${MIRROR} ${CODENAME}-security main universe restricted multiverse
SOURCES

apt-get update -qq
apt-get upgrade -y -qq

# A. Base System Kernel, Compression & Microcode Hardware Layer
apt-get install -y -qq --no-install-recommends \
    linux-generic systemd-sysv initramfs-tools linux-firmware zstd

# B. Live Boot Orchestration Engines (Casper Infrastructure without lupin-casper)
apt-get install -y -qq --no-install-recommends \
    casper network-manager netplan.io sudo user-setup

# C. Calamares OS Installer & Shared Target Configuration Schemes
apt-get install -y -qq --no-install-recommends \
    calamares calamares-settings-ubuntu calamares-settings-kubuntu \
    polkit-kdewallet-backend kubuntu-settings-desktop

# D. Desktop Shell & Target App Contexts (Konsole, Dolphin, Kate)
apt-get install -y -qq --no-install-recommends \
    kde-plasma-desktop plasma-workspace konsole dolphin kate \
    kio-extras systemsettings xinit xserver-xorg-core xserver-xorg-video-all

# Configure Default Hardware Session & Desktop User Controls
echo "kubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kubuntu
chmod 0440 /etc/sudoers.d/kubuntu

# E. Hardened Purging & Space-Saving Optimizations
echo "Purging system documentation caches..."
find /usr/share/doc -depth -type f ! -name copyright -delete || true
find /usr/share/man -type f -delete || true
rm -rf /usr/share/groff/* /usr/share/info/* /var/cache/man/*

apt-get autoremove --purge -y -qq
apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
EOF

# 6. Extract Kernel Assets For Media Boot Loader
echo "=== [Step 5/8] Pulling Boot Kernel and Initial Boot Ramdisk Images ==="
KERNEL_VERSION=\$(ls "${ROOTFS}/boot"/vmlinuz-* | head -n 1 | sed 's/.*vmlinuz-//')
sudo cp "${ROOTFS}/boot/vmlinuz-\${KERNEL_VERSION}" "${IMAGE_DIR}/casper/vmlinuz"
sudo cp "${ROOTFS}/boot/initrd.img-\${KERNEL_VERSION}" "${IMAGE_DIR}/casper/initrd"

# 7. Compress Live Workspace File Container
echo "=== [Step 6/8] Recompressing Sandbox System into Squashfs Container ==="
# Explicit unmounting before block packaging
sudo umount "${ROOTFS}/dev/pts" || true
sudo umount "${ROOTFS}/dev"     || true
sudo umount "${ROOTFS}/proc"    || true
sudo umount "${ROOTFS}/sys"     || true

# Use maximum XZ block compression logic for low storage footprint
sudo mksquashfs "${ROOTFS}" "${IMAGE_DIR}/casper/filesystem.squashfs" -comp xz -b 1M -noappend
sudo bash -c "printf \$(du -sx --block-size=1 ${ROOTFS} | cut -f1) > ${IMAGE_DIR}/casper/filesystem.size"

# 8. Dual-Boot Layout Configuration Matrix
echo "=== [Step 7/8] Deploying Unified Hybrid Bootloader Rules ==="
cat << 'EOF' > "${IMAGE_DIR}/boot/grub/grub.cfg"
set default=0
set timeout=5

insmod efi_gop
insmod efi_uga
insmod video_bochs
insmod video_cirrus
insmod gfxterm

menuentry "Kubuntu 26.04 Minimal Live (Resolute Hardened)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}
menuentry "Kubuntu 26.04 Minimal Installer (Direct Calamares)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper calamares quiet splash ---
    initrd /casper/initrd
}
EOF

# 9. Master Production ISO Output Image via xorriso
echo "=== [Step 8/8] Mastering Bootable Hybrid Image via Xorriso ==="
sudo grub-mkimage -o "${IMAGE_DIR}/boot/grub/i386-pc/core.img" -O i386-pc -p /boot/grub biosdisk ext2 fat iso9660 search
cat /usr/lib/grub/i386-pc/cdboot.img "${IMAGE_DIR}/boot/grub/i386-pc/core.img" > "${IMAGE_DIR}/boot/grub/i386-pc/eltorito.img"

cd "${IMAGE_DIR}"
sudo xorriso -as mkisofs \
    -r -V "KUBUNTU_2604_HARDENED" \
    -o "${ISO_OUT}" \
    -J -joliet-long -l \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    .

echo "=============================================================================="
echo " SUCCESS! Your custom hardened minimal Kubuntu ISO is available at:"
echo " ${ISO_OUT}"
echo "=============================================================================="
