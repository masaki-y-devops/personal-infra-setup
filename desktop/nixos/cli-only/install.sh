#!/usr/bin/env bash

cat << OUTPUT > ./install.sh
#!/usr/bin/env bash

set_userpref() {
	NIXOS_VER=25.05
	OWNER=nixuser
	}

set_diskname() {
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
	
	## partition name
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
cat << REST | sudo tee -a /mnt/etc/nixos/configuration.nix
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
	groups.video.members = [ "\${OWNER}" ];
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

 services.sshd.enable = true;

 programs.sway.enable = true;
}
REST
}

run_installation() {
	## sudo groupadd -g 30000 nixbld
	sudo useradd -u 30000 -g nixbld -G nixbld nixbld
	sudo --preserve-env=PATH,NIX_PATH,LC_ALL \$(which nixos-install) --root /mnt --no-root-password
}

## main section

set_userpref && echo "Setting user preferences variables are set."
set_diskname
# set_netdevicename   ## no longer needed to detect network devices to install

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

run_installation
OUTPUT

chmod +x ./install.sh

if ping -c 1 google.com ; then
        echo "Internet connection: OK."
else
        echo "Connect the internet."
        read -p "Press Enter to exit."
        exit 1
fi

## build tmp nix package manager
yes | sh <(curl -L https://nixos.org/nix/install) --daemon

## run install.sh
cat ./install.sh | exec bash -l
