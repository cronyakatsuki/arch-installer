#!/bin/sh

## == My arch installer script == ##
#part1 installer iso
printf '\033c'
echo "Welcome, lets start this shi*t"
echo "Enabling parallel downloads and updating keyring"
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 10/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring

echo "Loading croatian keys"
loadkeys croat

echo "Connect to wifi if needed"
echo """Steps to connect
[iwd]# device list
[iwd]# station device scan
[iwd]# station device get-networks
[iwd]# station device connect SSID
"""
iwctl
echo "Setting ntp"
timedatectl set-ntp true
printf '\033c'

echo "Listing drives"
lsblk
echo "Enter the drive: "
read drive
cfdisk $drive

printf '\033c'
lsblk
echo "Enter the linux partition: "
read partition
mkfs.btrfs -f -L ARCH $partition

read -p "Did you also create swap partition? [y/n]: " answer
[[ $answer = "y" ]] && read -p "Enter swap partition: " swappartition
[[ ! -z ${swappartition+x} ]] && mkswap -L SWAP $swappartition

read -p "Did you also create efi partition? [y/n]: " answer
[[ $answer = y ]] && read -p "Enter EFI partition: " efipartition
[[ ! -z ${efipartition+x} ]] && mkfs.vfat -F 32 $efipartition

echo "Setting up btrfs subvolumes"
mount $partition /mnt
cd /mnt
echo "Creating root subvolume"
btrfs subvolume create /mnt/@
echo "Creating home subvolume"
btrfs subvolume create /mnt/@home
echo "Creating cache subvolume"
btrfs subvolume create /mnt/@cache
echo "Creating log subvolume"
btrfs subvolume create /mnt/@log
echo "Unmounting root volume"
cd ~
umount -R /mnt

echo "Mounting the system"
echo "Mounting root btrs subvolume"
mount $partition -o subvol=/@ /mnt
echo "Mounting home btrs subvolume"
mkdir -p /mnt/home
mount $partition -o subvol=/@home /mnt/home
echo "Mounting cache btrs subvolume"
mkdir -p /mnt/var/cache
mount $partition -o subvol=/@cache /mnt/var/cache
echo "Mounting log btrs subvolume"
mkdir -p /mnt/var/log
mount $partition -o subvol=/@log /mnt/var/log

if [[ ! -z ${efipartition+x} ]]; then
    echo "Mounting efi partition"
    mkdir -p /mnt/boot
    mount $efipartition /mnt/boot
fi

if [[ ! -z ${swappartition+x} ]]; then
    echo "Mounting swap partition"
    swapon $swappartition
fi

echo "Installing basic system packages"
echo "Do you have an intel or amd cpu, or none? [intel/amd/none]: "
read intelamd
if [ $intelamd = "intel" ]; then
    pacstrap /mnt base linux-firmware linux-lts btrfs-progs intel-ucode
elif [ $intelamd = "amd" ]; then
    pacstrap /mnt base linux-firmware linux-lts btrfs-progs amd-ucode
elif [ $intelamd = "none" ]; then
    pacstrap /mnt base linux-firmware linux-lts btrfs-progs
fi

echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Generating chroot part of the script"
sed '1,/^#part2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh
rm -rf /mnt/arch_install2.sh
exit

#part2
printf '\033c'
pacman -Syu
pacman -S --noconfirm --needed sed
echo "Setting up pacman settings."
sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "s/^#CheckSpace/CheckSpace/" /etc/pacman.conf
sed -i "s/^#VerbosePkgLists/VerbosePkgLists/" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 10/" /etc/pacman.conf
sed -i "s/^ParallelDownloads = 10/&\nILoveCandy/" /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Syu

echo "Setting up time zone"
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
echo "Setting up locale"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=croat" > /etc/vconsole.conf

echo "Setting up hostname and networking"
echo "Enter hostname: "
read hostname
echo $hostname > /etc/hostname
echo "127.0.0.1       localhost" >> /etc/hosts
echo "::1             localhost" >> /etc/hosts
echo "127.0.1.1       $hostname.localdomain $hostname" >> /etc/hosts
mkinitcpio -P

echo "Downloading and setting better mirrorlist"
pacman -S --noconfirm --needed reflector rsync
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --latest 200 --sort rate --save /etc/pacman.d/mirrorlist


echo "Setting up network managment"
pacman -S --noconfirm networkmanager dhcpcd openresolv
systemctl enable NetworkManager
systemctl enable dhcpcd
echo "Setting better dns servers as defaults"
sed -i 's/#name_servers=127.0.0.1/name_servers="94.140.14.14 94.140.15.15 2a10:50c0::ad1:ff 2a10:50c0::ad2:ff"/' /etc/resolvconf.conf

echo "Setting up xorg, gpu drivers and my xorg configs"
pacman -S --needed --noconfirm xorg-server-common xorg-xsetroot xorg-xinit xorg-xinput xwallpaper xdotool

echo "Do you have an amd gpu/igpu [y/n]: "
read amd
[[ $amd = "y" ]] && pacman -S --needed --noconfirm xf86-video-amdgpu

echo "Do you have an nvidia gpu/dgpu [y/n]: "
read nvidia
[[ $nvidia = "y" ]] && pacman -S --needed --noconfirm nvidia-dkms nvidia-settings

echo "Are you running this in virtualbox? install virtualbox-guest-utils [y/n]"
read virtualbox
[[ $virtualbox = "y" ]] && pacman -S --needed --noconfirm virtualbox-guest-utils

echo "Do you have nvidia optimus [y/n]: "
read optimus
[[ $optimus = "y" ]] && [[ $nvidia = "y" ]] && pacman -S --needed --noconfirm nvidia-prime

echo "Setting xorg configurations"

mkdir -p /etc/X11/xorg.conf.d
echo "Section "InputClass"
	Identifier "My Mouse"
	Driver "libinput"
	MatchIsPointer "yes"
	Option "AccelProfile" "flat"
	Option "AccelSpeed" "0"
EndSection" > /etc/X11/xorg.conf.d/50-mouse-acceleration.conf

echo "Section "ServerFlags"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
    Option "BlankTime" "0"
EndSection" > /etc/X11/xorg.conf.d/10-monitor.conf

echo "Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "hr"
        Option "XkbOptions" "caps:escape"
EndSection" > /etc/X11/xorg.conf.d/00-keyboard.conf

echo "Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "ClickMethod" "clickfinger"
        Option "NaturalScrolling" "true"
        Option "ScrollMethod" "edge"
EndSection" > /etc/X11/xorg.conf.d/40-libinput.conf

echo "Do you wanna preload amdgpu with mkinitcpio.conf [y/n]: "
read preload_amdgpu
[[ $preload_amdgpu = "y" ]] && sed -i 's/MODULES=()/MODULES=(amdgpu)/' /etc/mkinitcpio.conf

echo "Setting up grub"
pacman --noconfirm -S grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

if [[ $nvidia = "y" ]]; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 nmi_watchdog=0 zswap.enabled=0 rcutree.rcu_idle_gp_delay=1"/' /etc/default/grub
else
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 nmi_watchdog=0 zswap.enabled=0"/' /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo "Do you wanna disable sp5100_tco driver for amd to disable it's watchdog (Can help with shutdown errors) [y/n]: "
read sp5100_tco
if [[ $sp5100_tco = "y" ]]; then
    mkdir -p /etc/modprobe.d
    echo "blacklist sp5100_tco" > /etc/modprobe.d/sp5100_tco.conf
fi

echo "Do you wanna set up better swappiness settings [y/n]: "
read swap_settings
if [[ $swap_settings = "y" ]]; then
    mkdir -p /etc/sysctl.d
    echo "vm.swappiness = 10" > /etc/sysctl.d/99-swappiness.conf
    echo "vm.vfs_cache_pressure=50" > /etc/sysctl.d/99-vfs_cache_pressure.conf
fi

echo "Do you wanna disable network manager powersave [y/n]: "
read networkmanager_powersave
if [[ $networkmanager_powersave = "y" ]]; then 
    mkdir -p /etc/NetworkManager/conf.d
    echo "[connection]
    wifi.powersave = 2" > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
fi

echo "Have an ssd? Enable fstrim and make it run daily [y/n]: "
read ssd
if [[ $ssd = "y" ]]; then
    mkdir -v /etc/systemd/system/fstrim.timer.d
    touch /etc/systemd/system/fstrim.timer.d/override.conf
    echo "[Timer]
    OnCalendar=
    OnCalendar=daily" > /etc/systemd/system/fstrim.timer.d/override.conf
    systemctl enable fstrim.timer
fi

echo "Do you wanna enable zram (uses half the ram) [y/n]: "
read zram
if [[ $zram = "y" ]]; then
    pacman -S --noconfirm --needed zram-generator
    echo '[zram0]
    zram-size = ram / 2' > /etc/systemd/zram-generator.conf
fi

echo "Do you wan't to disable hibernation [y/n]: "
read hibernation
[[ $hibernation = "y" ]] && systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

[[ $nvidia = "y" ]] && read -p "Do you wanna enable a fix for /oldroot/ during shutdown with nvidia? [y/n]: " oldroot_fix
if [[ $oldroot_fix = "y" ]]; then
    mkdir -p /usr/lib/systemd/system-shutdown
    echo "#!/bin/sh
    # remove nvidia modules
    /usr/bin/modprobe -r nvidia_drm nvidia_modeset nvidia_uvm && /usr/bin/modprobe -r nvidia" > /usr/lib/systemd/system-shutdown/nvidia.shutdown
fi

echo "Installing basic packages and enabling basic services"
pacman -S --noconfirm zsh p7zip unzip xclip \
    pacman-contrib wireless_tools man pcmanfm \
    pipewire pipewire-pulse pipewire-alsa rtkit \
    alsa-plugins alsa-tools alsa-utils pulsemixer pamixer \
    firefox playerctl lxsession bluez bluez-utils syncthing \
    keepassxc thunderbird maim xdotool bat acpid \
    ufw hugo python-pygments python-gitpython \
    ccache smartmontools libreoffice-still aria2

ufw enable
ufw logging off
systemctl enable rtkit-daemon.service
systemctl enable bluetooth.service
systemctl enable acpid.service

echo "Set root password"
passwd

echo "Setting up user"

echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Enter Username: "
read username
useradd -m -G wheel -s /bin/zsh $username
usermod -a $username -G network
usermod -a $username -G video
usermod -a $username -G input
usermod -a $username -G audio


echo "Setting up makepkg.conf"
sed -i 's/-march=native/-march=x86-64 -mtune=generic/' /etc/makepkg.conf
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf

ai3_path=/home/$username/arch_install3.sh
sed '1,/^#part3$/d' arch_install2.sh > $ai3_path
chown $username:$username $ai3_path
chmod +x $ai3_path
su -c $ai3_path -s /bin/sh $username
rm -rf $ai3_path
echo "Pre-Installation Finish Reboot now"
exit

#part3
echo "Setting up paru"
sudo pacman -S --noconfirm --needed go rust nodejs npm cmake git
git clone https://aur.archlinux.org/paru.git
cd paru
makepgk -si
cd ..
rm -rf paru

echo "Getting my dotfiles"
mkdir ~/repos
cd ~/repos
git clone https://github.com/cronyakatsuki/dots
cd ~
mkdir ~/.config

echo "Setting up my zsh config and scripts"
paru -S --needed --noconfirm zsh zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting starship pfetch-btw glow
ln -s $HOME/repos/dots/.zshenv $HOME/.zshenv
ln -s $HOME/repos/dots/.config/zsh/* $/HOME/.config/zsh
ln -s $HOME/repos/dots/.config/zsh/.* $/HOME/.config/zsh
ln -s $HOME/repos/dots/.config/starship.toml $HOME/.config/starship
ln -s $HOME/repos/dots/bin $HOME/bin

echo "Setting up xdg user dirs"
echo 'XDG_DESKTOP_DIR="$HOME/.local/share/desktop"
XDG_DOWNLOAD_DIR="$HOME/downs"
XDG_TEMPLATES_DIR="$HOME/.local/share/templates"
XDG_PUBLICSHARE_DIR="$HOME/.local/share/public"
XDG_DOCUMENTS_DIR="$HOME/docs"
XDG_MUSIC_DIR="$HOME/music"
XDG_PICTURES_DIR="$HOME/pics"
XDG_VIDEOS_DIR="$HOME/vids"' > $HOME/.config/user-dirs.dirs
mkdir -p $HOME/.local/share/desktop
mkdir -p $HOME/downs
mkdir -p $HOME/.local/share/templates
mkdir -p $HOME/.local/share/public
mkdir -p $HOME/docs
mkdir -p $HOME/music
mkdir -p $HOME/pics
mkdir -p $HOME/vids

echo "Setting up neovim"
sudo pacman -S --noconfirm --needed neovim ripgrep
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

git clone https://github.com/cronyakatsuki/nvim-conf ~/.config/nvim

echo "Setting up slock"
git clone https://github.com/cronyakatsuki/slock.git ~/repos/slock
cd ~/repos/slock
sudo make install clean

echo "Setting up dmenu and dmenu scripts"
git clone https://github.com/cronyakatsuki/dmenu.git ~/repos/dmenu
cd ~/repos/dmenu
sudo make install clean
git clone https://github.com/cronyakatsuki/dmenu-scripts.git ~/repos/dmenu-scripts
ln -s $HOME/repos/dmenu-scripts $HOME/bin/dmenu

paru -S --needed --noconfirm brillo dmenu-bluetooth clipmenu-git xdg-ninja-git tutanota-desktop-bin ferdium-bin colorpicker yt-dlp --noconfirm

cd ~/repos/dots
make $(cat Makefile | grep -E '.*:.*' | column -t -s ':' | fzf --multi --prompt "Choose what part of the configs you wanna install: " | awk '{ print $1 }')

echo "Do you wan't to setup gaming related packages, settings and optimizations? [y/n]"
read gaming
if [[ $gaming = "y" ]]; then
    if pacman -Qi nvidia-dkms > /dev/null; then
        echo "Installing nvidia drivers"
        sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
    fi

    if pacman -Qi xf86-video-amdgpu > /dev/null; then
        echo "Installing amdgpu drivers"
        sudo pacman -S --noconfirm --needed lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
    fi
    
    echo "Installing wine dependencies"
    sudo pacman -S --needed --noconfirm wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
    mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
    lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
    sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
    ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 \
    lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader

    echo "Installing gaming related software"
    paru -S --needed --noconfirm lib32-gamemode-git gamemode-git lib32-mangohud-git mangohud-common-git mangohud-git steam \
            lutris python-magic winetricks protontricks proton-ge-custom-bin \
            heroic-games-launcher-bin libstrangle-git --needed --noconfirm

    ln -s $HOME/repos/dots/.config/gamemode.ini $HOME/.config/gamemode.init
    ln -s $HOME/repos/dots/.config/Mangohud $HOME/.config/Mangohud

    echo "Setting up gamemode"
    sudo usermod -a `whoami` -G gamemode
    echo "@gamemode       -       nice    10" | sudo tee -a /etc/security/limits.conf
    echo '<driconf>
   <device>
       <application name="Default">
           <option name="vblank_mode" value="0" />
       </application>
   </device>
</driconf>' > /etc/drirc

    echo "Creating the default wine prefix folder"
    mkdir -p $HOME/.local/share/wineprefixes/default
fi
