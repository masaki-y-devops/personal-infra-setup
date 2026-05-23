{ config, pkgs, ... }:

{
 imports = [
	./hardware-configuration.nix
	];

 # bootloader
 boot.loader.systemd-boot.enable = true;
 boot.loader.efi.canTouchEfiVariables = true;
 
 # users
 users = {
	users.masaki = {
		name = "masaki";
		isNormalUser = true;
		extraGroups = [ "wheel" ];
		};
 };

 # timezone
 time.timeZone = "Asia/Tokyo";

 # system packages
 system.stateVersion = "23.11";
 nixpkgs.config.allowUnfree = true;
 environment.systemPackages = with pkgs; [
	nano
	vim
	neofetch
	haskellPackages.xmobar
	rofi
	feh
	lxterminal
	firefox
	(vivaldi.override {
		proprietaryCodecs = true;
		enableWidevine = false;
		})
	xfce.thunar
	xfce.xfce4-icon-theme
	freetube
	];

 # network
 networking.hostName = "WIN1";
 networking.wireless.iwd.enable = true;
 networking.useDHCP = false;
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

 # xserver
 environment.pathsToLink = [ "/libexec" ];
 services.xserver = {
	enable = true;
	autorun = false;
	videoDrivers = [ "intel" ];
	deviceSection = ''
		Option "DRI" "2"
		Option "TearFree" "true"
	'';
	monitorSection = ''
		Option "Rotate" "right"
	'';
	libinput = {
		enable = true;
		touchpad = {
			tapping = true;
			naturalScrolling = true;
			disableWhileTyping = true;
			};
		};
	desktopManager.xterm.enable = false;
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
		config = builtins.readFile /home/masaki/.config/xmonad/xmonad.hs;
	};
 };

 fonts = {
	enableDefaultPackages = true;
	fontDir.enable = true;
	packages = with pkgs; [
		ubuntu_font_family
		ipafont
		];
	fontconfig = {
		defaultFonts = {
			serif = ["Ubuntu Regular" "Ubuntu Regular"];
			sansSerif = ["Ubuntu Regular" "Ubuntu Regular"];
			monospace = ["Ubuntu Mono Regular" "Ubuntu Mono Regular"];
			};
		};
 };

 i18n.inputMethod = {
	enabled = "fcitx5";
	fcitx5.addons = [ pkgs.fcitx5-mozc ];
 };

 sound.enable = true;
 hardware.pulseaudio.enable = true;

 environment = {
	interactiveShellInit = ''
		alias up="sudo nixos-rebuild switch --upgrade-all"
	'';
	loginShellInit = ''
		startx >/dev/null 2>&1
	'';
 };
}
