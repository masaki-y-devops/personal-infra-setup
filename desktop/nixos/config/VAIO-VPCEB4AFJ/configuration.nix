{ config, lib, pkgs, ... }:

{
 imports = [
	./hardware-configuration.nix
	];

 # bootloader
 boot.loader.grub = {
	enable = true;
	device = "/dev/sda";
	};

 # users
 users = {
	users.masaki = {
		name = "masaki";
		isNormalUser = true;
		extraGroups = [ "wheel" "libvirtd" ];
		};
	groups.video.members = [ "masaki" ];
 };

 # timezone and i18n
 time.timeZone = "Asia/Tokyo";
 i18n.defaultLocale = "en_US.UTF-8";
 console.keyMap = "jp106";

 # System Packages
 system.stateVersion = "23.05";
 nixpkgs.config.allowUnfree = true;
 environment.systemPackages = with pkgs; [
	nano
	vim
	neofetch
	haskellPackages.xmobar
	feh
	rofi
	lxterminal
	firefox-esr
	(vivaldi.override {
		proprietaryCodecs = true;
		enableWidevine = false;
		})
	vivaldi-ffmpeg-codecs
	xfce.thunar
	xfce.xfce4-icon-theme
	freetube
	vscode
	];

 # kernel
 boot.kernelParams = [ "quiet" "modprobe.blacklist=ath9k" ];
 boot.extraModulePackages = [ config.boot.kernelPackages.rtl8821au ];
 zramSwap.enable = true;

 # network
 networking.hostName = "VAIO-VPCEB4AFJ";
 networking.useDHCP = lib.mkForce false;
 networking.dhcpcd.enable = false;
 networking.wireless.iwd.enable = true;
 boot.initrd.systemd.network.enable = true;
 systemd.network = {
	enable = true;
	networks = {
		"30-wlan0" = {
			matchConfig.Name = "wlan0";
			networkConfig.DHCP = "yes";
			};
		"35-eth0" = {
			matchConfig.Name = "eth0";
			networkConfig.DHCP = "yes";
			};
		};
 };

 networking.firewall = {
	enable = true;
	extraCommands = ''
		iptables -P INPUT DROP
		iptables -P FORWARD DROP
		iptables -P OUTPUT ACCEPT
		iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -A INPUT -i lo -j ACCEPT
		ip6tables -P INPUT DROP
		ip6tables -P FORWARD DROP
		ip6tables -P OUTPUT ACCEPT
		ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		ip6tables -A INPUT -i lo -j ACCEPT
	'';
 };

 # X server
 environment.pathsToLink = [ "/libexec" ];
 services.xserver = {
	enable = true;
	autorun = false;
	layout = "jp";
	videoDrivers = [ "radeon" ];
	deviceSection = ''
		Option "TearFree" "on"
		'';
	libinput.enable = true;
	libinput.touchpad = {
		tapping = true;
		naturalScrolling = true;
		disableWhileTyping = true;
		};
	desktopManager = {
		xterm.enable = false;
		};
	displayManager = {
		defaultSession = "none+xmonad";
		lightdm.enable = false;
		startx.enable = true;
		};
	windowManager.xmonad = {
		enable = true;
		enableContribAndExtras = true;
		extraPackages = hpkgs: [
			hpkgs.xmonad-contrib
			hpkgs.xmonad-extras
			hpkgs.xmonad
			];
		config = builtins.readFile /home/masaki/.xmonad/xmonad.hs;
	};
  };

 hardware.opengl = {
	enable = true;
	extraPackages = with pkgs; [
		vaapiVdpau
		libvdpau-va-gl
		];
 };

 # fonts
 fonts = {
	enableDefaultPackages = true;
	fontDir.enable = true;
	packages = with pkgs; [
		ubuntu_font_family
		ipafont
		];
	fontconfig = {
		defaultFonts = {
			serif = ["Ubuntu Regular"];
			sansSerif = ["Ubuntu Regular"];
			monospace = ["Ubuntu Mono Regular"];
			};
		};
  };

 # japanese input
 i18n.inputMethod = {
	enabled = "fcitx5";
	fcitx5.addons = [ pkgs.fcitx5-mozc ];
 };

 # PulseAudio
 sound.enable = true;
 hardware.pulseaudio.enable = true;

 # udev
 services.udev = {
	enable = true;
	extraRules = ''
		ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video $sys$devpath/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w $sys$devpath/brightness"
		'';
 };

 # gvfs
 services.gvfs.enable = true;

 # icons
 services.xserver.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

 # bash_profile and bashrc
 environment = {
	interactiveShellInit = ''
		alias up="sudo nixos-rebuild switch --upgrade-all"
		cd ~/Downloads
		neofetch
	'';
	loginShellInit = ''
		startx >/dev/null 2>&1
	'';
  	};

 # virt-manager
 virtualisation.libvirtd.enable = true;
 virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
 programs.virt-manager.enable = true;

}
