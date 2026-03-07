#!/usr/bin/env bash

## Changelog
## 2025-11-10
## - Added Sway floating settings from previous scripts
## 2025-11-09
## - Changed DNS from Cloudflare to AdGuard
## - Added Wofi
## - Changed Wofi menu shortcut from Win-Enter to Alt-Space (correspond to Windows Powertoys command palette)
## - Added quiet boot parameters

## Set overall script behavior
## Stop scripts immediately when error occurs
## set -eu -o pipefail

## Specify some variables manually
TMP=~

MAINSRV=https://fastly.mirror.pkgbuild.com
SUBSRV=https://mirror.rackspace.com

USERNAME=arch
USERPASS=initpass
ROOTPASS=initpassroot

## Other variables detection
echo "Setting Current System Infomation to Variables..."

## echo "Setting network interface name..."
## NETDEVICE=`ip a | grep "state UP" | awk '{print $2}'`
## NETDEVICE=${NETDEVICE::-1}

echo "Setting CPU vendor..."
VENDORID=`lscpu | grep "Vendor ID:" | awk '{print $3}'`
if [ "${VENDORID}" = "GenuineIntel" ]; then
    CPU=intel
else
    CPU=amd
fi
echo "CPU vendor is ${CPU}."

echo "Setting VGA vendor..."
if [ "$(lspci | grep VGA | grep -o NVIDIA)" = "NVIDIA" ]; then
	VGA=nvidia
elif [ "$(lspci | grep VGA | grep -o ATI)" = "ATI" ]; then
	VGA=ati
elif [ "$(lspci | grep VGA | grep -o AMD)" = "AMD" ]; then
	VGA=amdgpu
else
	VGA=intel
fi
echo "VGA vendor is ${VGA}."

echo "Setting target block device..."
DISK=`lsblk | grep -E "8:0|179:0|259:0" | awk '!/part|run/ {print $1}'`
if [[ "${DISK}" =~ "nvme0n1" ]]; then
        DISK=nvme0n1
elif [[ "${DISK}" =~ "nvme1n1" ]]; then
        DISK=nvme1n1
else
        :
fi

if [[ "${DISK}" =~ "mmcblk0" ]]; then
        DISK=mmcblk0
elif [[ "${DISK}" =~ "mmcblk1" ]]; then
        DISK=mmcblk1
else
        :
fi
echo "DISK is ${DISK}."

echo "Setting partition name..."
if [ "${DISK}" = "mmcblk0" ] || [ "${DISK}" = "mmcblk1" ]; then
        DISK1=${DISK}p1
        DISK2=${DISK}p2
elif [ "${DISK}" = "nvme0n1" ] || [ "${DISK}" = "nvme1n1" ]; then
        DISK1=${DISK}p1
        DISK2=${DISK}p2
else
        DISK1=${DISK}1
        DISK2=${DISK}2
fi
echo "Your partition structure contains ${DISK1} and ${DISK2}."

echo "Building temporary installation environment..."
echo "Downloading tarball..."
if curl --output-dir ${TMP} --remote-name-all ${MAINSRV}/iso/latest/{archlinux-bootstrap-x86_64.tar.zst,sha256sums.txt}; then
	echo "Files are downloaded from ${MAINSRV}."
else
	curl --output-dir ${TMP} --remote-name-all ${SUBSRV}/iso/latest/{archlinux-bootstrap-x86_64.tar.zst,sha256sums.txt}
	echo "Files are downloaded from ${SUBSRV}."
fi

echo "Downloading signature file from archlinux.org..."
curl --output-dir ${TMP} -O https://archlinux.org/iso/latest/archlinux-bootstrap-x86_64.tar.zst.sig

echo "Verifying tarball..."
CHECKSUM=`sha256sum -c ${TMP}/sha256sums.txt 2>&1 | grep OK | awk '{print $2}'`
if [ "${CHECKSUM}" = "OK" ]; then
    echo "Checksum OK."
else
    echo "Checksum failed. Stopped."
    read -p "Press enter to exit."
	exit 1
fi

gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org
VERIFY=`gpg --keyserver-options auto-key-retrieve --verify ${TMP}/archlinux-bootstrap-x86_64.tar.zst.sig ${TMP}/archlinux-bootstrap-x86_64.tar.zst 2>&1 | grep "Good" | awk '{print $2}'`
if [ "${VERIFY}" = "Good" ]; then
    echo "Verification OK."
else
    echo "Verification failed. Stopped."
    read -p "Press enter to exit."
	exit 1
fi

echo "Unpacking tarball..."
sudo tar xvf ${TMP}/archlinux-bootstrap-x86_64.tar.zst -C ${TMP} --numeric-owner

echo "Setting tmp pacman configuration..."
cat << MIRRORLIST | sudo tee ${TMP}/root.x86_64/etc/pacman.d/mirrorlist
Server = ${MAINSRV}/\$repo/os/\$arch
Server = ${SUBSRV}/\$repo/os/\$arch
MIRRORLIST

sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' ${TMP}/root.x86_64/etc/pacman.conf

echo "Mounting tmp environment..."
sudo mount --rbind ${TMP}/root.x86_64 ${TMP}/root.x86_64
sudo mount -t proc /proc ${TMP}/root.x86_64/proc
sudo mount -t sysfs /sys ${TMP}/root.x86_64/sys
sudo mount --rbind /dev ${TMP}/root.x86_64/dev
sudo mount --rbind /run ${TMP}/root.x86_64/run
sudo mount --make-rslave ${TMP}/root.x86_64/sys
sudo mount --make-rslave ${TMP}/root.x86_64/dev
sudo mount --make-rslave ${TMP}/root.x86_64/run
sudo mount --bind /sys/firmware/efi/efivars ${TMP}/root.x86_64/sys/firmware/efi/efivars

echo "Copying resolv.conf to tmp environment..."
sudo cp -L /etc/resolv.conf ${TMP}/root.x86_64/etc/resolv.conf

echo "Getting into installation environment using chroot..."
cat <<-INSTALLENV | sudo chroot ${TMP}/root.x86_64
	pacman-key --init
	pacman-key --populate
	pacman -Syu --noconfirm
	pacman -S --noconfirm parted dosfstools efibootmgr

	## Cleaning unused uefi nvram entries if it exists
	EFIENTRY=$(efibootmgr -v | grep -E "^Boot00[0-9][0-9]*" | grep -v UEFI | awk '{print $1}' | cut -b 5-8 | xargs)
	if [[ -n "${EFIENTRY}" ]]; then
		for i in ${EFIENTRY}; do
			efibootmgr -b $i -B
		done
		echo "EFI entries are deleted."
	else
		echo "No EFI entries."
	fi

	## Perform Partitoning
	parted -s /dev/${DISK} mklabel gpt
	parted -s /dev/${DISK} mkpart "esp" fat32 1MiB 513MB
	parted -s /dev/${DISK} set 1 esp on
	parted -s /dev/${DISK} mkpart "root" ext4 513MB 100%

	## Create filesystem
	yes | mkfs.vfat -F32 /dev/${DISK1}
	yes | mkfs.ext4 /dev/${DISK2}

	## Mounting partitions
	mount /dev/${DISK2} /mnt
	mkdir /mnt/boot
	mount /dev/${DISK1} /mnt/boot

	## Installing base system
	pacstrap /mnt base linux{,-firmware} ${CPU}-ucode efibootmgr sudo iwd

	## Generating fstab
	cat <<-FSTAB > /mnt/etc/fstab
		/dev/disk/by-partlabel/root / ext4 defaults 0 1
		/dev/disk/by-partlabel/esp /boot vfat defaults 0 2
	FSTAB

INSTALLENV

echo "Mounting /mnt again..."
sudo mount /dev/$DISK2 /mnt
sudo mount /dev/$DISK1 /mnt/boot

sudo mount -t proc /proc /mnt/proc
sudo mount -t sysfs /sys /mnt/sys
sudo mount --rbind /dev /mnt/dev
sudo mount --rbind /run /mnt/run
sudo mount --make-rslave /mnt/sys
sudo mount --make-rslave /mnt/dev
sudo mount --make-rslave /mnt/run

sudo mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars

sudo cp -L /etc/resolv.conf /mnt/etc/resolv.conf

cat << MIRRORLIST | sudo tee /mnt/etc/pacman.d/mirrorlist
Server = ${MAINSRV}/\$repo/os/\$arch
Server = ${SUBSRV}/\$repo/os/\$arch
MIRRORLIST

sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /mnt/etc/pacman.conf

echo "Getting into chroot environment and Running essential configuration..."
cat <<-INITSETUP | sudo chroot /mnt
	## locale settings
	echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
	echo "LANG=en_US.UTF-8" > /etc/locale.conf

	## Set root and user password for initial login, change it later for security
	echo -e "${ROOTPASS}\n${ROOTPASS}" | passwd
	useradd -m -g wheel ${USERNAME}
	echo -e "${USERPASS}\n${USERPASS}" | passwd ${USERNAME}

	## add user to /etc/sudoers
	echo '${USERNAME} ALL=(ALL:ALL) ALL' | EDITOR='tee -a' visudo

	## for udev backlight
	gpasswd -a ${USERNAME} video
	
	## Install bootloader (and additional kernel modules for gpd win1)
	if [ $(lscpu | grep "Model name" | grep -o "Z8750") = "Z8750" ]; then
		efibootmgr \
		-c -g -d /dev/${DISK} \
		-p 1 -L "archlinux" -l /vmlinuz-linux \
		-u 'root=PARTLABEL=root rw initrd=${CPU}-ucode.img initrd=initramfs-linux.img quiet \
		dmi_product_name=GPD-WINI55 acpi_vendor=native'
		sed -i 's/MODULES=()/MODULES=(pwm-lpss pwm-lpss-platform)/' /etc/mkinitcpio.conf
		mkinitcpio -p linux
	else
		efibootmgr \
		-c -g -d /dev/${DISK} \
		-p 1 -L "archlinux" -l /vmlinuz-linux \
		-u 'root=PARTLABEL=root rw initrd=${CPU}-ucode.img initrd=initramfs-linux.img quiet'
	fi

	## Generate systemd-networkd config to use DHCP
	cat <<-WLAN > /etc/systemd/network/25-wl.network
		[Match]
		Name=wl*

		[Network]
		DHCP=yes
	WLAN

	cat <<-ETH > /etc/systemd/network/30-en.network
		[Match]
		Name=en*

		[Network]
		DHCP=yes
	ETH

	## Set AdGuard Public DNS server
	cat <<-RESOLVCONF > /etc/resolv.conf
		nameserver 94.140.14.14
		nameserver 94.140.15.15
	RESOLVCONF

	## Autostart network feature on boot
	systemctl enable systemd-networkd iwd

	## Installing Other Apps
	pacman -S --noconfirm wayland seatd wlr-randr sway i3status pulseaudio \
	otf-ipafont ttf-ubuntu-font-family fcitx5{,-gtk,-qt,-mozc,-configtool} kwindowsystem \
	nano swaybg wofi firefox lxterminal thunar gvfs

	usermod -aG seat ${USERNAME}
	systemctl enable seatd

	systemctl mask dev-tpmrm0.device

	## Installing Wayland driver
	if [ "${VGA}" = "nvidia" ]; then
		pacman -S --noconfirm mesa
	elif [ "${VGA}" = "ati" ]; then
		:
	elif [ "${VGA}" = "amdgpu" ]; then
		:
	else
		pacman -S --noconfirm mesa
	fi
INITSETUP

## configure system to handle some errors

## hide kernel error messages on console login screen
cat << 'PRINTK' | sudo tee /mnt/etc/sysctl.d/20-quiet-printk.conf
	kernel.printk = 3 3 3 3
PRINTK
	
## add udev rules and add user to video group to adjust brightness at user privileges
cat <<-'UDEV' | sudo tee /mnt/etc/udev/rules.d/backlight.rules
	ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"
UDEV
	
## fix sound pop-noise issues on snd-hda-Intel
cat <<-FIXNOISE | sudo tee /mnt/etc/modprobe.d/snd-hda-intel.conf
	options snd_hda_intel power_save=0
FIXNOISE

## Generate sway config
sudo mkdir -p /mnt/home/${USERNAME}/.config/{sway,i3status}

cat << 'SWAYCONFIG' | sudo tee /mnt/home/${USERNAME}/.config/sway/config
# i3 config file (v4)

## fonts 
font pango:Ubuntu Regular 13

## i3status
bar {
 status_command i3status
 position top
 tray_output none
 colors {
  focused_workspace  #000000 #000000 #ffffff
  active_workspace   #000000 #000000 #ffffff
  inactive_workspace #000000 #000000 #666666
  }
}

## variables
## Mod1 is Alt key
## Mod4 is Win key
set $mod Mod4
set $nsi --no-startup-id
set $ws workspace
set $mc move container to workspace

## keybinds
## apps
bindsym $mod+Return exec $nsi wofi --show run
bindsym $mod+BackSpace kill
bindsym $mod+f exec $nsi firefox
bindsym $mod+l exec $nsi lxterminal

## volumes
bindsym XF86AudioMute exec $nsi pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioRaiseVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
bindsym XF86AudioLowerVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%
bindsym F2 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
bindsym F1 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%

## brightness
bindsym $mod+d exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) - 1` > /sys/class/backlight/intel_backlight/brightness
bindsym $mod+u exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) + 1` > /sys/class/backlight/intel_backlight/brightness

## workspaces
bindsym $mod+1 $ws 1
bindsym $mod+2 $ws 2
bindsym $mod+3 $ws 3
bindsym $mod+q $mc 1; $ws 1
bindsym $mod+w $mc 2; $ws 2
bindsym $mod+e $mc 3; $ws 3

## autostart
exec $nsi fcitx5
exec $nsi swaybg -i ~/Wallpapers/wallpaper.jpg

## display scaling
## To detect display name, use "swaymsg -t get_outputs"
## set 1.5 for GPD Pocket1
output DSI-1 scale 1.0

## window border settings
default_border pixel 0

## window floating settings
## to get app_id or instance or class, use "swaymsg -t get_tree"
floating_maximum_size 960 x 540
for_window [floating] move position center

for_window [window_role="dialog"] floating enable
for_window [window_role="pop-up"] floating enable
for_window [window_role="bubble"] floating enable
for_window [window_role="task_dialog"] floating enable
for_window [window_role="menu"] floating enable

for_window [title="^Settings$"] floating enable
for_window [title="^Preferences$"] floating enable
for_window [title="^Settings$"] floating enable

for_window [title="^About Mozilla Firefox$" app_id="firefox"] floating enable
for_window [title="Extension:" app_id="firefox"] floating enable
for_window [app_id="com.nextcloud.desktopclient.nextcloud"] floating enable
for_window [instance="org.cryptomator.launcher.Cryptomator"] floating enable
SWAYCONFIG

cat << I3STCONFIG | sudo tee /mnt/home/${USERNAME}/.config/i3status/config
general {
 colors = false
 }

order += "volume master"
order += "ethernet _first_"
order += "wireless wlan0"
order += "battery 0"
order += "time"

volume master {
 format = "VOL.%volume"
 format_muted = "VOL.muted"
 device = "default"
 mixer = "Master"
 mixer_idx = 0
 }

ethernet _first_ {
 format_up = "Ethernet"
 format_down = ""
}

wireless wlan0 {
 format_up = "%essid"
 format_down = "No connection"
 }

battery 0 {
 format = "%percentage %status"
 last_full_capacity = true
 format_percentage = "%.00f%s"
 ## this is for GPD Win1 or Pocket1
 ## path = "/sys/class/power_supply/max170xx_battery/uevent"
 }

time {
 format = "%Y/%m/%d %H:%M"
}
I3STCONFIG

cat << BASHPROFILE | sudo tee /mnt/home/${USERNAME}/.bash_profile
exec sway
BASHPROFILE

## fix home directory ownerships
## it is required to work ~/.config directory e.g. pulseaudio
cat << FIXUSRDIR | sudo chroot /mnt
chown -R ${USERNAME}: /home/${USERNAME}
FIXUSRDIR
         
echo "Installation completed. Reboot."
