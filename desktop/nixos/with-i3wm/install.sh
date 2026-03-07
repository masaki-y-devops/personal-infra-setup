#!/usr/bin/env bash

## write temp install.sh
cat << INSTALLSH > ~/install.sh
#!/usr/bin/env bash

## Define functions

set_userpref() {
	NIXOS_VER=25.05
	OWNER=nixuser
	}

set_diskname() {
	## system disk name
	if [ "\$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "nvme0n1")" = "nvme0n1" ]; then
		DISK=nvme0n1
	elif [ "\$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "nvme1n1")" = "nvme1n1" ]; then
		DISK=nvme1n1
	elif [ "\$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "mmcblk0")" = "mmcblk0" ]; then
		DISK=mmcblk0
	elif [ "\$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "mmcblk1")" = "mmcblk1" ]; then
		DISK=mmcblk1
	else
		DISK=sda
	fi
	
	## partition number
	if [ "\$DISK" == "mmcblk0" ] || [ "\$DISK" == "mmcblk1" ]; then
		DISK1=\${DISK}p1
		DISK2=\${DISK}p2
	elif [ "\$DISK" == "nvme0n1" ] || [ "\$DISK" == "nvme1n1" ]; then
        DISK1=\${DISK}p1
        DISK2=\${DISK}p2
	else
        DISK1=\${DISK}1
        DISK2=\${DISK}2
	fi
	echo "Target Diskname is \${DISK}. Target Partition name is \${DISK1} and \${DISK2}."
	read -p "Press Enter key to proceed." 
	}

# set_netdevicename() {
#	NETDEVICE=\$(ip a | grep "state UP" | awk '{print \$2}')
#	NETDEVICE=\${NETDEVICE::-1}
#	}

setup_nix_install_env() {
	export NIX_PATH=/nix/var/nix/profiles/per-user/root/channels/nixos
	export PATH="\$PATH:/usr/sbin:/sbin:/run/current-system/sw/bin"
	export LC_ALL=C
	sudo \$(which nix-channel) --update
	sudo \$(which nix-channel) --remove nixpkgs
	sudo \$(which nix-channel) --remove nixos
	sudo \$(which nix-channel) --add https://nixos.org/channels/nixos-\${NIXOS_VER} nixos
	sudo \$(which nix-channel) --update
	nix-env -f '<nixpkgs>' -iA nixos-install-tools
	}

delete_current_efientries() {
	EFIENTRY=\$(efibootmgr -v | grep -E "^Boot00[0-9][0-9]*" | grep -v UEFI | awk '{print $1}' | cut -b 5-8 | xargs)
        if [[ -n "\${EFIENTRY}" ]]; then
                for i in \${EFIENTRY}; do
                        sudo efibootmgr -b \$i -B
                done
	else
		:
	fi
	}

delete_current_part() {
	PARTNUM=\$(lsblk | grep \${DISK} | grep part | wc -l)
	if [ \${PARTNUM} -ge 1 ]; then
		i=1
		while [ \$i -le "\${PARTNUM}" ]; do
			sudo parted -s /dev/\${DISK} rm \$i
			((i++))
		done
	else
		:
	fi
	}

create_part_for_uefi() {
	sudo parted -s /dev/\$DISK mklabel gpt
	sudo parted -s /dev/\$DISK mkpart "esp" fat32 1MiB 513MB
	sudo parted -s /dev/\$DISK set 1 esp on
	sudo parted -s /dev/\$DISK mkpart "root" ext4 513MB 100%
	yes | sudo mkfs.vfat -F32 /dev/\${DISK1}
	sudo mkfs.ext4 -F /dev/\${DISK2}
	sudo tune2fs -O ^orphan_file /dev/\${DISK2}
	sudo e2fsck -f -y /dev/\${DISK2}
	}

create_part_for_bios() {
	sudo parted -s /dev/\$DISK mklabel msdos
	sudo parted -s /dev/\$DISK mkpart primary ext4 1MiB 513MB
	sudo parted -s /dev/\$DISK set 1 boot on
	sudo parted -s /dev/\$DISK mkpart primary ext4 513MB 100%
	sudo mkfs.ext4 -F /dev/\${DISK1}
	sudo mkfs.ext4 -F /dev/\${DISK2}
	}

mount_part() {
	sudo mount /dev/\${DISK2} /mnt
	sudo mkdir /mnt/boot
	sudo mount /dev/\${DISK1} /mnt/boot
	}

initialize_config() {
	sudo \$(which nixos-generate-config) --root /mnt
	## remove default config and write minimal config
	sudo rm -rf /mnt/etc/nixos/configuration.nix
	}

write_config_for_uefi() {
cat << UEFI | sudo tee /mnt/etc/nixos/configuration.nix
{ config, lib, pkgs, ... }:

let
	unstable = import (builtins.fetchTarball "https://github.com/nixos/nixpkgs/tarball/nixos-unstable") {};
in
{
 imports = [
	./hardware-configuration.nix
	];

 # filesystem
 fileSystems."/" = lib.mkForce {
	device = "/dev/disk/by-partlabel/root";
	fsType = "ext4";
 };

 fileSystems."/boot" = lib.mkForce {
	device = "/dev/disk/by-partlabel/esp";
	fsType = "vfat";
 };	

 # bootloader
 boot.loader = {
 systemd-boot.enable = true;
 efi.canTouchEfiVariables = true;
 };

UEFI
}

write_config_for_bios() {
cat << BIOS | sudo tee /mnt/etc/nixos/configuration.nix
{ config, lib, pkgs, ... }:

let
	unstable = import (builtins.fetchTarball "https://github.com/nixos/nixpkgs/tarball/nixos-unstable") {};
in
{
 imports = [
	./hardware-configuration.nix
	];

 # bootloader
 boot.loader.grub = {
	enable = true;
	device = "/dev/\${DISK}";
	};
		
BIOS
}

write_config_for_the_rest() {
cat << RESTCONFIG | sudo tee -a /mnt/etc/nixos/configuration.nix
 # blocked kernel modules found by lsmod
 boot.blacklistedKernelModules = [ "tpm" ];
 
 # kernel modules for wi-fi dongle
 boot.extraModulePackages = [ config.boot.kernelPackages.rtl8821au ];

 # users
 users = {
	users.\${OWNER} = {
		name = "\${OWNER}";
		isNormalUser = true;
		initialPassword = "initpass";
		extraGroups = [ "wheel" ];
		};
	groups.video.members = [ "${OWNER}" ];
	 };

 system.activationScripts.stdio = lib.mkForce {
    text = ''
		chown -R ${OWNER}: /home/${OWNER}
    '';
	};

 # timezone and i18n
 time.timeZone = "Asia/Tokyo";
 i18n.defaultLocale = "en_US.UTF-8";
 console.keyMap = "us"; ## jp106 or us

 # System Packages
 system.stateVersion = "\${NIXOS_VER}";
 environment.systemPackages = with pkgs; [
	nano
	vim
	i3status
	wofi
	swaybg
	lxterminal
	firefox
	xfce.thunar
	nextcloud-client
	cryptomator
	];

 # network
 networking.hostName = "nixos";
 networking.wireless.iwd.enable = true;
 networking.useDHCP = lib.mkForce false;
 networking.dhcpcd.enable = false;
 systemd.network = {
	enable = true;
	networks = {
		"30-wlan0" = {
			matchConfig.Name = "wlan0";
			networkConfig.DHCP = "yes";
			};
		};
 };

 networking.firewall = {
	enable = true;
	extraCommands = ''
		iptables -A INPUT -i lo -j ACCEPT
		iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		
		iptables -A OUTPUT -o lo -j ACCEPT
		iptables -A OUTPUT -o tailscale0 -j ACCEPT
		iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -A OUTPUT -p tcp -m state --state NEW --dport 80 -j ACCEPT
		iptables -A OUTPUT -p tcp -m state --state NEW --dport 443 -j ACCEPT
		iptables -A OUTPUT -p udp -m state --state NEW --dport 53 -j ACCEPT
		iptables -A OUTPUT -p tcp -m state --state NEW --dport 53 -j ACCEPT
		
		iptables -P INPUT DROP
		iptables -P FORWARD DROP
		iptables -P OUTPUT DROP
		ip6tables -P INPUT DROP
		ip6tables -P FORWARD DROP
		ip6tables -P OUTPUT DROP
		'';
 };

 services.tailscale = {
	enable = true;
	package = unstable.tailscale;
	};

 programs.sway.enable = true;
 
 # gnome-keyring
 services.gnome.gnome-keyring.enable = true;
 security.pam.services.login.enableGnomeKeyring = true;

 # fonts
 fonts = {
	enableDefaultPackages = true;
	fontDir.enable = true;
	packages = with pkgs; [
		ipafont
		];
	fontconfig = {
		defaultFonts = {
			serif = [ "IPAPGothic" ];
			sansSerif = [ "IPAPGothic" ];
			monospace = [ "Monospace" ];
			};
		};
	};
	
 # fcitx5-mozc
 i18n.inputMethod = {
	enabled = "fcitx5";
	fcitx5.addons = [ pkgs.fcitx5-mozc ];
	};
	
 # gvfs
 services.gvfs.enable = true;

RESTCONFIG
}

## escape "$" twice using '' and \ to preserve udev rules from variables expansion
write_ext_config() {
cat << 'EXT' | sudo tee -a /mnt/etc/nixos/configuration.nix
 # udev
 services.udev = {
	enable = true;
	extraRules = ''
		ACTION=="add", SUBSYSTEM=="backlight", RUN+="\${pkgs.coreutils}/bin/chgrp video \$sys\$devpath/brightness", RUN+="\${pkgs.coreutils}/bin/chmod g+w \$sys\$devpath/brightness"
		'';
	};
}
EXT
}

run_installation() {
	sudo \$(which nix-channel) --update
	sudo \$(which nix-channel) --remove nixpkgs
	sudo \$(which nix-channel) --remove nixos
	sudo \$(which nix-channel) --add https://nixos.org/channels/nixos-\${NIXOS_VER} nixos
	sudo \$(which nix-channel) --update
	## sudo groupadd -g 30000 nixbld
	sudo useradd -u 30000 -g nixbld -G nixbld nixbld
	sudo --preserve-env=PATH,NIX_PATH,LC_ALL \$(which nixos-install) --root /mnt --no-root-password
}

## main section
set_userpref && echo "Setting user preferences variables are set."
set_diskname

#### set_netdevicename  ## no longer needed to detect network devices to install

setup_nix_install_env

delete_current_part

if [ -d /sys/firmware/efi/efivars ]; then
	delete_current_efientries
	create_part_for_uefi
else
	create_part_for_bios
fi

mount_part
initialize_config

if [ -d /sys/firmware/efi/efivars ]; then
	write_config_for_uefi
else
	write_config_for_bios
fi

write_config_for_the_rest

write_ext_config

run_installation
INSTALLSH

## make install.sh executable
chmod +x ~/install.sh

## check network connection to proceed installation
if ping -c 1 google.com ; then
        echo "Internet connection: OK."
else
        echo "Connect the internet."
        read -p "Press Enter to exit."
        exit 1
fi

## build tmp nix package manager
## Updated on 20250617 to add curl options
yes | sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

## run install.sh
cat ~/install.sh | exec bash -l

## write sway,i3status config
sudo mkdir -p /mnt/home/${OWNER}/.config/{sway,i3status}
cat << 'SWAY' | sudo tee -a /mnt/home/${OWNER}/.config/sway/config
# i3 config file (v4)

## fonts 
font pango:IPAPGothic 11

## title bar and border config
client.focused          #000000 #000000 #ffffff #000000 #000000
client.focused_inactive #000000 #000000 #666666 #000000 #000000
client.unfocused        #000000 #000000 #666666 #000000 #000000
client.urgent           #000000 #000000 #666666 #000000 #000000
client.placeholder      #000000 #000000 #666666 #000000 #000000

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
bindsym $mod+t floating toggle

bindsym $mod+f exec $nsi firefox
bindsym $mod+l exec $nsi lxterminal
bindsym $mod+n exec $nsi nextcloud
bindsym $mod+c exec $nsi flatpak run org.cryptomator.cryptomator

## volumes
bindsym XF86AudioMute exec $nsi pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioRaiseVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
bindsym XF86AudioLowerVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%
bindsym F2 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
bindsym F1 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%

## brightness
bindsym XF86MonBrightnessDown exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) - 100` > /sys/class/backlight/intel_backlight/brightness
bindsym XF86MonBrightnessUp exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) + 100` > /sys/class/backlight/intel_backlight/brightness

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
exec $nsi eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg)
exec $nsi export SSH_AUTH_SOCK

## window settings
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
SWAY

cat <<-'I3STATUS' | sudo tee -a /mnt/home/${OWNER}/.config/i3status/config
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
I3STATUS

echo "finished."
