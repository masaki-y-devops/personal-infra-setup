{ config, lib, pkgs, ... }:

{
 imports = [
	./hardware-configuration.nix
	];

 # bootloader
 boot.loader = {
	systemd-boot.enable = true;
	efi.canTouchEfiVariables = true;
	};

 # kernel
 ## boot.kernelParams = [ "quiet" "loglevel=0" ];
 ## boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

 # hide kernel error messages on login console
 boot.kernel.sysctl = {
	"kernel.printk" = "3 3 3 3";
	};

 # microcode
 hardware.cpu.intel.updateMicrocode = true;

 # zram
 zramSwap = {
	enable = true;
	memoryPercent = 300;
	algorithm = "lz4";
	};

 # tmpfs
 boot.tmp = {
	useTmpfs = true;
	cleanOnBoot = true;
	};

 fileSystems."/var/tmp" = {
	device = "none";
	fsType = "tmpfs";
	options = [ "size=4G" "rw" "noatime" ];
	};

 fileSystems."/var/cache" = {
	device = "none";
	fsType = "tmpfs";
	options = [ "rw" "noatime" ];
	};

 fileSystems."/home/masaki/.cache" = {
	device = "none";
	fsType = "tmpfs";
	options = [ "size=4G" "rw" "noatime" ];
	};

 # users
 users = {
	users.masaki = {
		name = "masaki";
		isNormalUser = true;
		extraGroups = [ "wheel" "lp" "vboxusers" ];
		};
	groups.video.members = [ "masaki" ];
 };

 # timezone and i18n
 time.timeZone = "Asia/Tokyo";
 i18n.defaultLocale = "en_US.UTF-8";
 ## console.keyMap = "us"; ## jp106 or us
 ## console.font = "latarcyrheb-sun32";

 # network
 networking.hostName = "MicroPC";
 networking.wireless.iwd.enable = true;
 networking.useDHCP = lib.mkForce false;
 networking.dhcpcd.enable = false;

 systemd.network = {
	enable = true;
	networks = {
		## This is for wi-fi module
		"30-wlan0" = {
			matchConfig.Name = "wlan0";
			networkConfig.DHCP = "yes";
			};
		## This is for USB tethering
		"40-enp0s21f0u2" = {
			matchConfig.Name = "enp0s21f0u2";
			networkConfig.DHCP = "yes";
			};
		## This is for Bluetooth tethering
		"45-bnep0" = {
			matchConfig.Name = "bnep0";
			networkConfig.DHCP = "yes";
			networkConfig.IPv6SendRA = "yes";
			};
		};
  };

 environment.etc."resolv.conf" = {
	text = lib.mkForce "nameserver 1.1.1.1\nnameserver 1.0.0.1";
	};

 # System Packages
 system.stateVersion = "23.11";
 nixpkgs.config.allowUnfree = true;
 environment.systemPackages = with pkgs; [
	vim
	haskellPackages.xmobar
	feh
	rofi
	lxterminal
	(vivaldi.override {
		proprietaryCodecs = true;
		enableWidevine = false;
		}
	)
	xfce.thunar
	xfce.xfce4-icon-theme
	freetube
	librewolf
	vscode
	mpv
	];

 programs.firefox = {
	enable = true;
	package = pkgs.firefox-esr;
	preferences = {
		"gfx.webrender.all" = true;
		"gfx.webrender.software.d3d11" = false;
		"media.ffmpeg.vaapi.enabled" = true;
		"media.hardware-video-decoding.force-enabled" = true;
		"browser.cache.disk.enable" = false;
		"browser.cache.memory.max_entry_size" = 512000;
		"browser.cache.check_doc_frequency" = 0;
		"general.smoothScroll" = false;
		"media.videoControls.picture-in-picture.enabled" = false;
		"browser.toolbars.bookmarks.showOtherBookmarks" = false;
		"browser.toolbars.bookmarks.visibility" = "never";
		"browser.tabs.loadBookmarksInTabs" = true;
		"browser.tabs.openintab" = true;
		"browser.link.open_newwindow.restriction" = 0;
		"browser.backspace_action" = 0;
		"extensions.pocket.enabled" = false;
		"geo.enabled" = false;
		};
	policies = {
		DisableTelemetry = true;
		DisableFirefoxStudies = true;
		};
 };
		
 # X server
 environment.pathsToLink = [ "/libexec" ];
 services.xserver = {
	enable = true;
	autorun = false;
	xkb.options = "ctrl:nocaps";
	xkb.layout = "us"; ## "us" or "jp"
	xkb.model = "pc104"; ## "pc104" or "jp106"
	videoDrivers = [ "intel" ];
	deviceSection = ''
		Option "TearFree" "true"
		'';
	desktopManager.xterm.enable = false;
	displayManager = {
		defaultSession = "none+xmonad";
		lightdm.enable = false;
		startx.enable = true;
		};
	windowManager.xmonad = {
		enable = true;
		enableContribAndExtras = true;
		config = builtins.readFile /home/masaki/.xmonad/xmonad.hs;
	};
 };

 # bash_profile
 environment.loginShellInit = ''
	startx >/dev/null 2>&1
 	'';

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
			serif = [ "Ubuntu Regular" ];
			sansSerif = [ "Ubuntu Regular" ];
			monospace = [ "Ubuntu Mono Regular" ];
			};
		};
	};

 # sound
 sound.enable = true;
 hardware.pulseaudio = {
	enable = true;
	package = pkgs.pulseaudioFull;
	};
 hardware.pulseaudio.daemon.config = {
	default-sample-format = "float32le";
	default-sample-rate = "384000";
	alternate-sample-rate = "384000";
	resample-method = "soxr-vhq";
	};

 # irqbalance
 services.irqbalance.enable = true;

 # fcitx-mozc
 i18n.inputMethod = {
	enabled = "fcitx5";
	fcitx5.addons = [ pkgs.fcitx5-mozc ];
	};

 # gtk dark theme
 environment.extraInit = ''
	export XDG_CONFIG_DIRS="/etc/xdg:$XDG_CONFIG_DIRS"
	'';

 environment.etc."xdg/gtk-3.0/settings.ini".text = ''
	[Settings]
	gtk-application-prefer-dark-theme = true
	'';

 # bashrc
 environment.interactiveShellInit = ''
	cd ~/Downloads
	'';

 # udev for backlight
 services.udev = {
 	enable = true;
 	extraRules = ''
 		ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video $sys$devpath/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w $sys$devpath/brightness"
 		'';
 };

 # gvfs
 services.gvfs.enable = true;
 
 # bluetooth
 hardware.bluetooth = {
	enable = true;
	powerOnBoot = true;
	settings.General.Enable = "Source,Sink,Media,Socket";
 };

 # virtualbox
 virtualisation.virtualbox.host.enable = true;

}
