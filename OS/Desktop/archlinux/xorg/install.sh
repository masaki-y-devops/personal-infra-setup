#!/usr/bin/env bash

## Set overall script behavior
## Stop scripts immediately when error occurs
## set -eu -o pipefail

## Specify some variables manually
TMP=~

MAINSRV=https://mirror.osbeck.com/archlinux
SUBSRV=https://al.arch.niranjan.co

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
    exit 0
fi

gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org
VERIFY=`gpg --keyserver-options auto-key-retrieve --verify ${TMP}/archlinux-bootstrap-x86_64.tar.zst.sig ${TMP}/archlinux-bootstrap-x86_64.tar.zst 2>&1 | grep "Good" | awk '{print $2}'`
if [ "${VERIFY}" = "Good" ]; then
    echo "Verification OK."
else
    echo "Verification failed. Stopped."
    exit 0
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
	
	## Install bootloader
	efibootmgr \
	-c -g -d /dev/${DISK} \
	-p 1 -L "archlinux" -l /vmlinuz-linux \
	-u 'root=PARTLABEL=root rw initrd=${CPU}-ucode.img initrd=initramfs-linux.img'

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

	## Set cloudflare DNS server
	cat <<-RESOLVCONF > /etc/resolv.conf
		nameserver 1.1.1.1
		nameserver 1.0.0.1
	RESOLVCONF

	## Autostart network feature on boot
	systemctl enable systemd-networkd iwd

	## Installing Xorg and driver
	pacman -S --noconfirm xorg-server xorg-xinit xorg-xrandr
	if [ "${VGA}" = "nvidia" ]; then
		pacman -S --noconfirm nvidia
		cp /etc/mkinitcpio.conf /etc/mkinitcpio-custom.conf
		sed -i 's/^HOOKS=\(.*\)/HOOKS=(systemd autodetect modconf block filesystems fsck)/' /etc/mkinitcpio-custom.conf
		sed -i '/ALL_config=/s/^#//' /etc/mkinitcpio.d/linux.preset
		sed -i 's/mkinitcpio.conf/mkinitcpio-custom.conf/' /etc/mkinitcpio.d/linux.preset
		sed -i 's/^PRESETS=.*/PRESETS=('default')/' /etc/mkinitcpio.d/linux.preset
		rm -rf /boot/initramfs-linux*
		mkinitcpio -p linux
		## fix tearing
		cat <<-NVIDIA > /etc/X11/xorg.conf.d/20-nvidia.conf
			Section "Device"
			  Identifier "NVIDIA Card"
			  Driver "nvidia"
			  VendorName "NVIDIA Corporation"
			  BoardName "GeForce"
			EndSection

			Section "Screen"
			  Identifier "Screen0"
			  Device "Device0"
			  Monitor "Monitor0"
			  Option "ForceFullCompositionPipeline" "on"
			  Option "AllowIndirectGLXProtocol" "off"
			  Option "TripleBuffer" "on"
			EndSection
		NVIDIA
	elif [ "${VGA}" = "ati" ]; then
		pacman -S --noconfirm xf86-video-ati
		## fix tearing
		cat <<-ATI > /etc/X11/xorg.conf.d/20-radeon.conf
			Section "OutputClass"
			  Identifier "Radeon"
			  MatchDriver "radeon"
			  Driver "radeon"
			  Option "TearFree" "on"
			EndSection
		ATI
	elif [ "${VGA}" = "amdgpu" ]; then
		pacman -S --noconfirm xf86-video-amdgpu
	else
		pacman -S --noconfirm xf86-video-intel
		## fix tearing
		cat <<-INTEL > /etc/X11/xorg.conf.d/20-intel.conf
			Section "OutputClass"
			  Identifier "Intel Graphics"
			  Driver "intel"
			  Option "TearFree" "true"
			EndSection
		INTEL
	fi

	## Window Manager
	pacman -S --noconfirm i3-wm i3status

	## Install system apps
	## kwindowsystem is needed due to run fcitx5-configtool to enable mozc
	pacman -S --noconfirm \
	pulseaudio \
	otf-ipafont ttf-ubuntu-font-family \
	fcitx5{,-gtk,-qt,-mozc,-configtool} kwindowsystem \
	nano rofi
	
	## Install user apps
	pacman -S --noconfirm \
	firefox lxterminal thunar gvfs
	
INITSETUP

## configure system to handle some errors
## hide kernel error messages on console login screen
cat << 'PRINTK' | sudo tee /mnt/etc/sysctl.d/20-quiet-printk.conf
	kernel.printk = 3 3 3 3
PRINTK
	
## fix touchscreen on gpd win1 or pocket1
cat <<-GPDTOUCHFIX | sudo tee /mnt/usr/share/X11/xorg.conf.d/99-gpd-pocket-touchscreen.conf
	Section "InputClass"
	 Identifier "calibration"
	 MatchProduct "Goodix Capacitive TouchScreen"
	 Option       "TransformationMatrix"  "0 1 0 -1 0 1 0 0 1"
	EndSection
GPDTOUCHFIX
	
## add udev rules and add user to video group to adjust brightness at user privileges
cat <<-'UDEV' | sudo tee /mnt/etc/udev/rules.d/backlight.rules
	ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"
UDEV
	
## fix sound pop-noise issues on snd-hda-Intel
cat <<-FIXNOISE | sudo tee /mnt/etc/modprobe.d/snd-hda-intel.conf
	options snd_hda_intel power_save=0
FIXNOISE

## Generate i3wm config
sudo mkdir -p /mnt/home/${USERNAME}/.config/{i3,i3status}

cat << 'I3CONFIG' | sudo tee /mnt/home/${USERNAME}/.config/i3/config
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
set $mod Mod1
set $nsi --no-startup-id
set $ws workspace
set $mc move container to workspace

## keybinds
## apps
bindsym $mod+Return exec $nsi rofi -show run
bindsym $mod+BackSpace kill
bindsym $mod+f exec $nsi firefox
bindsym $mod+l exec $nsi lxterminal

## volumes
bindsym XF86AudioRaiseVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
bindsym F1 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%
bindsym XF86AudioLowerVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%
bindsym F2 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%

## brightness
bindsym $mod+u exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) - 1` > /sys/class/backlight/intel_backlight/brightness
bindsym $mod+i exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) + 1` > /sys/class/backlight/intel_backlight/brightness

## workspaces
bindsym $mod+1 $ws 1
bindsym $mod+2 $ws 2
bindsym $mod+3 $ws 3
bindsym $mod+q $mc 1; $ws 1
bindsym $mod+w $mc 2; $ws 2
bindsym $mod+e $mc 3; $mc 3

## autostart
exec $nsi fcitx5
exec $nsi feh --bg-fill ~/Wallpapers/*.{jpg,jpeg,png,webp}

## window settings
floating_maximum_size 1000x600
default_border pixel 0
for_window [floating] move position center
I3CONFIG

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
 format = "%Y/%m/%d %H:%M "
}
I3STCONFIG

cat << BASHPROFILE | sudo tee /mnt/home/${USERNAME}/.bash_profile
startx >/dev/null 2>&1
BASHPROFILE

cat << XINITRC | sudo tee /mnt/home/${USERNAME}/.xinitrc
## disable screensaver
xset s off -dpms

## roatate screen for GPD devices
# xrandr -o right
# xrandr --dpi 90

## enable touchscreen on firefox when it is available
export MOZ_USE_XINPUT2=1

sleep 1

## run i3wm
exec i3
XINITRC

## fix home directory ownerships
## it is required to work ~/.config directory e.g. pulseaudio
cat << FIXUSRDIR | sudo chroot /mnt
chown -R ${USERNAME} /home/${USERNAME}
FIXUSRDIR
         
echo "Installation completed. Reboot."
