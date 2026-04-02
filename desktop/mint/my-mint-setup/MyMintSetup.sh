#!/usr/bin/env bash

## various settings for my intel SoC (e.g. Z8750,N4120,m3-7Y30,m3-8100Y) umpc environments
VGA=$(lspci | grep "VGA" | grep -o "Intel")

if [ "${VGA}" = "Intel" ]; then
	cat <<-INTEL | sudo tee /etc/X11/xorg.conf.d/20-intel.conf   ## reducing VGA tearing
		Section "OutputClass"
		 Identifier "Intel Graphics"
		 Driver "intel"
		 Option "TearFree" "true"
		EndSection
	INTEL

	cat <<-FIXNOISE | sudo tee /etc/modprobe.d/snd-hda-intel.conf  ## reducing intel soundcard shutdown pop-noise
		options snd_hda_intel power_save=0
	FIXNOISE
else
	:
fi

## rotation settings for my gpd micropc, win 1st gen, pocket 1st gen
rotationfix() {
	cat <<-ROTATE | sudo tee /etc/lightdm/rotate.sh
		#!/usr/bin/env bash
		xrandr -o right
	ROTATE

	sudo chmod +x /etc/lightdm/rotate.sh
	
	cat <<-RDM | sudo tee /etc/lightdm/lightdm.conf.d/70-linuxmint.conf
		[SeatDefaults]
		user-session=xfce
		greeter-setup-script=/etc/lightdm/rotate.sh
	RDM
}

HOST=$(cat /etc/hostname | grep -o -e "micropc" -e "win1" -e "pocket") ## check hostname
if [ "${HOST}" = "micropc" ]; then
	rotationfix
elif [ "${HOST}" = "win1" ]; then
    rotationfix
elif [ "${HOST}" = "pocket" ]; then
	rotationfix
else
	: 
fi

## updates
sudo apt update && sudo apt upgrade -y

## uninstall unused fonts
sudo apt purge \
    fonts-noto-cjk fonts-noto-core fonts-dejavu-core fonts-dejavu-extra fonts-dejavu-mono \
	fonts-droid-fallback fonts-liberation fonts-mathjax fonts-noto-color-emoji fonts-noto-mono \
	fonts-opensymbol fonts-urw-base35 -y

## install essencial fonts
sudo apt install fonts-ipafont fcitx5-mozc -y

## uninstall unused apps
sudo apt purge \
    transmission-common transmission-gtk \
	thunderbird-locale-en-us thunderbird-locale-en \
	thunderbird librhythmbox-core10 rhythmbox-data \
	rhythmbox-plugin-tray-icon rhythmbox-plugins rhythmbox \
	mintchat hypnotix drawing warpinator timeshift simple-scan \
    gnome-calendar gnome-calculator xfce4-dict webapp-manager onboard \
    onboard-common rename gucharmap catfish gnome-disk-utility sticky \
    gnome-font-viewer seahorse xfce4-appfinder compiz compiz-gnome compiz-plugins-default compiz-plugins compizconfig-settings-manager \
    libcompizconfig0 python3-compizconfig mintbackup celluloid mintinstall mintdrivers mintwelcome mintstick \
    fingwit libpam-fingwit pix speech-dispatcher \
    libreoffice-{common,help-common,help-en-us,style-colibre,uiconfig-calc,uiconfig-common,uiconfig-draw,uiconfig-impress,uiconfig-writer} \
    -y

sudo apt autoremove -y

## ask user to continue or not
read -p "Press enter to continue userapp installation, press ctrl+c or close window to exit."

## install personal apps
# protonvpn
PVPNVER=1.0.8
wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_${PVPNVER}_all.deb
sudo dpkg -i ./protonvpn-stable-release_${PVPNVER}_all.deb && sudo apt update -y
sudo apt install proton-vpn-gnome-desktop -y
# dropbox
sudo apt install dropbox -y
# cryptomator
sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y && sudo apt update -y
sudo apt install cryptomator -y
# k3b
sudo apt install k3b -y
# openshot
sudo add-apt-repository ppa:openshot.developers/ppa -y && sudo apt update -y
sudo apt install openshot-qt python3-openshot -y
# mpv
sudo apt install mpv -y
# freetube
# yes | flatpak install flathub io.freetubeapp.FreeTube  ## not working, need to find alternative way to install

# virtualbox  ## unused state as I started to use QEMU/KVM
# after installing guest linuxmint, mount guestaddtions and run "sudo bash /path/to/guestadditionslinux.run"
#sudo apt install virtualbox virtualbox-guest-additions-iso -y
#sudo modprobe -r kvm{_intel,}
#cat << EOF | sudo tee /etc/modprobe.d/blacklist-kvm-for-virtualbox.conf
#blacklist kvm_intel
#blacklist kvm
#EOF
#sudo update-initramfs -u
#sudo gpasswd -a $(whoami) vboxusers