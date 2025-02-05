#!/bin/bash
set -e  # Exit on error

# ====== CONFIGURATION ======
TARGET_DISK="/dev/sdX"          # Replace with your disk (e.g., /dev/nvme0n1 or /dev/sda)
TIMEZONE="Europe/Stockholm"     # Replace if needed
# ===========================

# Detect partition naming scheme
if [[ $TARGET_DISK == *"nvme"* ]]; then
  PART_PREFIX="p"
else
  PART_PREFIX=""
fi

EFI_PART="${TARGET_DISK}${PART_PREFIX}1"
ROOT_PART="${TARGET_DISK}${PART_PREFIX}2"

# Unmount if previously mounted
umount -R /mnt 2>/dev/null || true

# Partitioning
parted --script "$TARGET_DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart primary ext4 513MiB 100%

# Formatting
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

# Mounting
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# Base system installation
pacstrap /mnt base linux mkinitcpio
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot setup
arch-chroot /mnt /bin/bash -ex <<EOF
# Timezone
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

# Initialize pacman keys
pacman-key --init
pacman-key --populate archlinux

# Install essentials
pacman -Sy --noconfirm gcc glibc git bash

# Clone and install custom init
git clone https://github.com/jaxilian/vos.git
cp -f vos/sbin/init /sbin/init
chmod +x /sbin/init
rm -rf vos

# Configure mkinitcpio (remove systemd hooks)
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# EFISTUB boot entry
efibootmgr --create --disk "$TARGET_DISK" --part 1 --label "VOS" \
  --loader /vmlinuz-linux \
  --unicode "initrd=\\initramfs-linux.img root=$ROOT_PART rw init=/sbin/init"
EOF

# Cleanup
umount -R /mnt
reboot