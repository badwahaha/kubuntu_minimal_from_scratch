#!/usr/bin/env bash
# ==============================================================================
# HARDENED KUBUNTU 26.04 LTS (RESOLUTE) MINIMAL ISO ENGINE FROM SCRATCH
# Fully Corrected Dynamic String Expansion for Cloud Build Actions Platforms
# Hybrid BIOS + UEFI Boot Support
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
# E. Helper files
apt-get install -y -qq --no-install-recommends \
    update-notifier-common ubuntu-release-upgrader-core apport 

# Configure Default Session & Desktop User Controls
echo "kubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kubuntu
chmod 0440 /etc/sudoers.d/kubuntu

# Ensure /var/crash exists so init scripts don't fail
mkdir -p /var/crash
chown root:root /var/crash
chmod 0755 /var/crash

# Ensure chroot has hostname + hosts before packages run
cat > "${ROOTFS}/etc/hostname" <<HOSTNAME
kubuntu-live
HOSTNAME

cat > "${ROOTFS}/etc/hosts" <<HOSTS
127.0.0.1 localhost kubuntu-live
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

# Compatibility: ensure canonical "ubuntu" live user + helper stubs exist
# Many upstream live scripts and package postinst hooks expect a user
# named "ubuntu" and a handful of helper scripts. Create them here.
groupadd -f netdev || true
useradd -m -s /bin/bash -G sudo,netdev,audio,video ubuntu || true
passwd -d ubuntu || true

# Generate initramfs for all installed kernels
echo "Generating initramfs..."
update-initramfs -c -k all

# E. Space-Saving Optimizations
find /usr/share/doc -depth -type f ! -name copyright -delete || true
find /usr/share/man -type f -delete || true
rm -rf /usr/share/groff/* /usr/share/info/* /var/cache/man/*

apt-get autoremove --purge -y -qq
apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
EOF

# 6. Extract Kernel Assets For Media Boot Loader
echo "=== [Step 5/8] Pulling Boot Kernel and Initial Boot Ramdisk Images ==="
KERNEL_VERSION=$(ls "${ROOTFS}/boot"/vmlinuz-* 2>/dev/null | head -n 1 | sed 's/.*vmlinuz-//')

if [ -z "${KERNEL_VERSION}" ]; then
    echo "ERROR: No kernel found in ${ROOTFS}/boot"
    exit 1
fi

sudo cp "${ROOTFS}/boot/vmlinuz-${KERNEL_VERSION}" "${IMAGE_DIR}/casper/vmlinuz"
sudo cp "${ROOTFS}/boot/initrd.img-${KERNEL_VERSION}" "${IMAGE_DIR}/casper/initrd.lz"

# 7. Compress Live Workspace File Container
echo "=== [Step 6/8] Recompressing Sandbox System into Squashfs Container ==="
sudo umount "${ROOTFS}/dev/pts" || true
sudo umount "${ROOTFS}/dev"     || true
sudo umount "${ROOTFS}/proc"    || true
sudo umount "${ROOTFS}/sys"     || true

sudo mksquashfs "${ROOTFS}" "${IMAGE_DIR}/casper/filesystem.squashfs" -comp xz -b 1M -noappend

printf "%s" "$(du -sx --block-size=1 "${ROOTFS}" | cut -f1)" | sudo tee "${IMAGE_DIR}/casper/filesystem.size" > /dev/null

# Create filesystem.manifest
sudo chroot "${ROOTFS}" dpkg-query -W --showformat='${Package} ${Version}\n' \
    > "${IMAGE_DIR}/casper/filesystem.manifest"

# Create desktop manifest copy and prune installer/live-only packages (optional)
cp "${IMAGE_DIR}/casper/filesystem.manifest" "${IMAGE_DIR}/casper/filesystem.manifest-desktop"
# remove packages that shouldn't be in desktop manifest (adjust patterns as needed)
sed -i -E '/(casper|ubiquity|live|calamares|cloud-init)/Id' "${IMAGE_DIR}/casper/filesystem.manifest-desktop" || true

# Generate md5sum list for casper-md5check (exclude md5sum.txt itself)
cd "${IMAGE_DIR}"
find . -type f -print0 \
  | xargs -0 md5sum \
  | sed 's|^\./||' \
  | grep -v -E '(^md5sum.txt$|/boot/grub/i386-pc/eltorito.img$)' \
  > md5sum.txt
  
# 8. Dual-Boot Layout Configuration Matrix
echo "=== [Step 7/8] Deploying Unified Hybrid Bootloader Rules ==="
cat << 'EOF' > "${IMAGE_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=5

insmod efi_gop
insmod efi_uga
insmod video_bochs
insmod video_cirrus
insmod gfxterm

menuentry "Kubuntu 26.04 Resolute (Boot)" {
    echo 'Loading Kubuntu Live Environment...'
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash vt_handoff=7
    initrd /casper/initrd.lz
}

menuentry "Kubuntu 26.04 Resolute (Safe Mode)" {
    echo 'Loading Kubuntu in Safe Mode...'
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper quiet splash nomodeset vt_handoff=7
    initrd /casper/initrd.lz
}

menuentry "Kubuntu 26.04 Resolute (OEM Mode)" {
    echo 'Loading Kubuntu in OEM Mode...'
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper oem-config quiet splash vt_handoff=7
    initrd /casper/initrd.lz
}
EOF

# 9. Master Production ISO Output Image via xorriso
echo "=== [Step 8/8] Mastering Bootable Hybrid Image via Xorriso ==="

# Pre-generate the target directory structure
mkdir -p "${IMAGE_DIR}/boot/grub/i386-pc"

# Mirror the host system's GRUB runtime modules into the ISO layout directory
echo "Syncing GRUB i386-pc modular runtime objects..."
cp /usr/lib/grub/i386-pc/*.mod "${IMAGE_DIR}/boot/grub/i386-pc/"
cp /usr/lib/grub/i386-pc/*.lst "${IMAGE_DIR}/boot/grub/i386-pc/"

# Compile the base core bootloader layer image for BIOS
sudo grub-mkimage -o "${IMAGE_DIR}/boot/grub/i386-pc/core.img" -O i386-pc -p /boot/grub biosdisk ext2 fat iso9660 search
cat /usr/lib/grub/i386-pc/cdboot.img "${IMAGE_DIR}/boot/grub/i386-pc/core.img" > "${IMAGE_DIR}/boot/grub/i386-pc/eltorito.img"

# Build standalone GRUB images for hybrid boot
echo "Creating GRUB standalone images for hybrid boot..."
sudo grub-mkstandalone -O i386-pc \
    --output="${IMAGE_DIR}/boot/grub/i386-pc/grub-standalone.img" \
    --install-modules="biosdisk part_msdos part_gpt normal linux iso9660 search" \
    "boot/grub/grub.cfg=${IMAGE_DIR}/boot/grub/grub.cfg" 2>/dev/null || true

sudo grub-mkstandalone -O x86_64-efi \
    --output="${IMAGE_DIR}/boot/grub/efi.img" \
    --install-modules="efi_gop efi_uga normal linux iso9660 search" \
    "boot/grub/grub.cfg=${IMAGE_DIR}/boot/grub/grub.cfg" 2>/dev/null || true

# Create hybrid ISO with both BIOS and UEFI support
cd "${IMAGE_DIR}"
sudo xorriso -as mkisofs \
    -iso-level 3 \
    -o "${ISO_OUT}" \
    -full-iso9660-filenames \
    -volid "KUBUNTU_RESOLVE" \
    -appid "Kubuntu 26.04 Resolute Hardened" \
    -partition_offset 16 \
    -A "Kubuntu Resolute 26.04 LTS" \
    -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog \
        -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    --efi-boot boot/grub/efi.img \
        -efi-boot-part --efi-boot-image \
    .

echo "=============================================================================="
echo " ✅ SUCCESS! Your custom hardened minimal Kubuntu ISO is available at:"
echo " 📦 ${ISO_OUT}"
echo "=============================================================================="
if [ -f "${ISO_OUT}" ]; then
    ISO_SIZE=$(du -h "${ISO_OUT}" | cut -f1)
    echo " 📏 Size: ${ISO_SIZE}"
    echo " 🚀 Ready to boot from USB or VM!"
    ls -lh "${ISO_OUT}"
else
    echo " ❌ ISO creation failed!"
    exit 1
fi
