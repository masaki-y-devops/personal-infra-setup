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

 # swap
 zramSwap = {
	enable = true;
	memoryPercent = 200;
	};

 # bootloader
 boot.loader = {
	systemd-boot.enable = true;
	efi.canTouchEfiVariables = true;
	};

 # cpu
 hardware.cpu.intel.updateMicrocode = true;

 # kernel
 boot.extraModulePackages = [ config.boot.kernelPackages.rtl8821au ];

 # users
 users = {
	users.masaki = {
		name = "masaki";
		isNormalUser = true;
		extraGroups = [ "wheel" ];
		};
	groups.video.members = [ "masaki" ];
 };

 # timezone and i18n
 time.timeZone = "Asia/Tokyo";
 i18n.defaultLocale = "en_US.UTF-8";
 console.keyMap = "jp106"; ## jp106 or us
 time.hardwareClockInLocalTime = true;
 
 # network
 networking.hostName = "Intel-Desktop";
 networking.useDHCP = lib.mkForce false;
 networking.dhcpcd.enable = false;
 networking.wireless.iwd.enable = true;
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

 environment.etc."resolv.conf" = {
	text = lib.mkForce "nameserver 1.1.1.1\nnameserver 1.0.0.1";
	};

 # System Packages
 system.stateVersion = "23.11";
 nixpkgs.config.allowUnfree = true;
 environment.systemPackages = with pkgs; [
	nano
	vim
	lm_sensors
	fastfetch
	haskellPackages.xmobar
	feh
	viewnior
	rofi
	lxterminal
	firefox-esr
	(vivaldi.override {
		proprietaryCodecs = true;
		enableWidevine = false;
		}
	)
	xfce.thunar
	## xfce.tumbler
	## ffmpegthumbnailer
	xfce.xfce4-icon-theme
	freetube
	rpcs3
	librewolf
	mpv
	vscode
	clamav
	libreoffice
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

 programs.steam.enable = true;

 # X server
 environment.pathsToLink = [ "/libexec" ];
 services.xserver = {
	enable = true;
	autorun = false;
	xkb.model = "jp106";
	xkb.layout = "jp";
	videoDrivers = [ "nvidia" ];
	screenSection = ''
		Option "ForceFullCompositionPipeline" "on"
		Option "AllowIndirectGLXProtocol" "off"
		Option "TripleBuffer" "on"
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

 environment.loginShellInit = ''
	## export GTK_IM_MODULE=fcitx5
	## export QT_IM_MODULE=fcitx5
	## export XMODIFIERS=@im=fcitx5
	startx >/dev/null 2>&1
 '';

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
 
 # for nvidia
 hardware.opengl = {
	enable = true;
	driSupport = true;
	driSupport32Bit = true;
	};

 hardware.nvidia = {
	modesetting.enable = true;
	powerManagement.enable = false;
	powerManagement.finegrained = false;
	open = false;
	nvidiaSettings = true;
	package = config.boot.kernelPackages.nvidiaPackages.stable;
 };

 # sound
 sound.enable = true;
 hardware.pulseaudio.enable = true;
 hardware.pulseaudio.daemon.config = {
	default-sample-format = "float32le";
	default-sample-rate = "384000";
	alternate-sample-rate = "384000";
	resample-method = "soxr-vhq";
	};

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
	## export TERM=xterm-mono
	'';

 # gvfs
 services.gvfs.enable = true;

 # irqbalance
 services.irqbalance.enable = true;

 # virtualbox
 # virtualisation.virtualbox.host = {
 #	enable = true;
 #	addNetworkInterface = true;
 #	enableExtensionPack = true;
 #	};

}

