#!/bin/sh

## == My arch installer script == ##
#part1 installer iso
printf '\033c'
printf '%s\n' "Welcome, lets start this shi*t"
printf '%s\n' "Enabling parallel downloads and updating keyring"
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 10/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring

printf '%s\n' "Loading croatian keys"
loadkeys croat

printf '%s\n' "Connect to wifi if needed"
printf '%s\n' """Steps to connect
[iwd]# device list
[iwd]# station device scan
[iwd]# station device get-networks
[iwd]# station device connect SSID
"""
iwctl
printf '%s\n' "Setting ntp"
timedatectl set-ntp true
printf '\033c'

printf '%s\n' "Listing drives"
lsblk
printf '%s\n' "Enter the drive: "
read drive
cfdisk $drive

printf '\033c'
lsblk
printf '%s\n' "Enter the linux partition: "
read partition
mkfs.btrfs -f -L ARCH $partition

read -p "Did you also create swap partition? [y/n]: " answer
[[ $answer = "y" ]] && read -p "Enter swap partition: " swappartition
[[ ! -z ${swappartition+x} ]] && mkswap -L SWAP $swappartition

read -p "Did you also create efi partition? [y/n]: " answer
[[ $answer = y ]] && read -p "Enter EFI partition: " efipartition
[[ ! -z ${efipartition+x} ]] && mkfs.vfat -F 32 $efipartition

printf '%s\n' "Setting up btrfs subvolumes"
mount $partition /mnt
cd /mnt
printf '%s\n' "Creating root subvolume"
btrfs subvolume create /mnt/@
printf '%s\n' "Creating home subvolume"
btrfs subvolume create /mnt/@home
printf '%s\n' "Creating cache subvolume"
btrfs subvolume create /mnt/@cache
printf '%s\n' "Creating log subvolume"
btrfs subvolume create /mnt/@log
printf '%s\n' "Unmounting root volume"
cd ~
umount -R /mnt

printf '%s\n' "Mounting the system"
printf '%s\n' "Mounting root btrs subvolume"
mount $partition -o subvol=/@ /mnt
printf '%s\n' "Mounting home btrs subvolume"
mkdir -p /mnt/home
mount $partition -o subvol=/@home /mnt/home
printf '%s\n' "Mounting cache btrs subvolume"
mkdir -p /mnt/var/cache
mount $partition -o subvol=/@cache /mnt/var/cache
printf '%s\n' "Mounting log btrs subvolume"
mkdir -p /mnt/var/log
mount $partition -o subvol=/@log /mnt/var/log

if [[ ! -z ${efipartition+x} ]]; then
    printf '%s\n' "Mounting efi partition"
    mkdir -p /mnt/boot
    mount $efipartition /mnt/boot
fi

if [[ ! -z ${swappartition+x} ]]; then
    printf '%s\n' "Mounting swap partition"
    swapon $swappartition
fi

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Installing basic system packages"
printf '%s\n' "Do you have an intel or amd cpu, or none? [intel/amd/none]: "
read intelamd
if [ $intelamd = "intel" ]; then
    pacstrap /mnt base linux-firmware linux-lts btrfs-progs intel-ucode
elif [ $intelamd = "amd" ]; then
    pacstrap /mnt base linux-firmware linux-lts btrfs-progs amd-ucode
elif [ $intelamd = "none" ]; then
    pacstrap /mnt base linux-firmware linux-lts btrfs-progs
fi

printf '%s\n' "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

printf '%s\n' "Generating chroot part of the script"
sed '1,/^#part2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh
rm -rf /mnt/arch_install2.sh

printf '%s\n' "Unmounting everything"
umount -R /mnt

if [[ ! -z ${swappartition+x} ]]; then
    printf '%s\n' "Unmouning swap partition"
swapoff $swappartition
fi


exit

#part2
printf '\033c'
pacman -Syu
pacman -S --noconfirm --needed sed
printf '%s\n' "Setting up pacman settings."
sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "s/^#CheckSpace/CheckSpace/" /etc/pacman.conf
sed -i "s/^#VerbosePkgLists/VerbosePkgLists/" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 10/" /etc/pacman.conf
sed -i "s/^ParallelDownloads = 10/&\nILoveCandy/" /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Syu

printf '%s\n' "Setting up time zone"
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
printf '%s\n' "Setting up locale"
printf '%s\n' "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
printf '%s\n' "LANG=en_US.UTF-8" > /etc/locale.conf
printf '%s\n' "KEYMAP=croat" > /etc/vconsole.conf

printf '%s\n' "Setting up hostname and networking"
printf '%s\n' "Enter hostname: "
read hostname
printf '%s\n' $hostname > /etc/hostname
printf '%s\n' "127.0.0.1       localhost" >> /etc/hosts
printf '%s\n' "::1             localhost" >> /etc/hosts
printf '%s\n' "127.0.1.1       $hostname.localdomain $hostname" >> /etc/hosts
mkinitcpio -P

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Downloading and setting better mirrorlist"
pacman -S --noconfirm --needed reflector rsync
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --latest 200 --sort rate --save /etc/pacman.d/mirrorlist

printf '%s\n' "Setting up network managment"
pacman -S --noconfirm networkmanager dhcpcd openresolv
systemctl enable NetworkManager
systemctl enable dhcpcd
printf '%s\n' "Setting better dns servers as defaults"
sed -i 's/#name_servers=127.0.0.1/name_servers="94.140.14.14 94.140.15.15 2a10:50c0::ad1:ff 2a10:50c0::ad2:ff"/' /etc/resolvconf.conf

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Setting up xorg, gpu drivers and my xorg configs"
pacman -S --needed --noconfirm xorg-server-common xorg-xsetroot xorg-xinit xorg-xinput xwallpaper xdotool

printf '%s\n' "Do you have an amd gpu/igpu [y/n]: "
read amd
[[ $amd = "y" ]] && pacman -S --needed --noconfirm xf86-video-amdgpu

printf '%s\n' "Do you have an nvidia gpu/dgpu [y/n]: "
read nvidia
[[ $nvidia = "y" ]] && pacman -S --needed --noconfirm nvidia-dkms nvidia-settings

printf '%s\n' "Are you running this in virtualbox? install virtualbox-guest-utils [y/n]"
read virtualbox
[[ $virtualbox = "y" ]] && pacman -S --needed --noconfirm virtualbox-guest-utils

printf '%s\n' "Do you have nvidia optimus [y/n]: "
read optimus
[[ $optimus = "y" ]] && [[ $nvidia = "y" ]] && pacman -S --needed --noconfirm nvidia-prime

printf '%s\n' "Setting xorg configurations"

mkdir -p /etc/X11/xorg.conf.d
printf '%s\n' "Section "InputClass"
	Identifier "My Mouse"
	Driver "libinput"
	MatchIsPointer "yes"
	Option "AccelProfile" "flat"
	Option "AccelSpeed" "0"
EndSection" > /etc/X11/xorg.conf.d/50-mouse-acceleration.conf

printf '%s\n' "Section "ServerFlags"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
    Option "BlankTime" "0"
EndSection" > /etc/X11/xorg.conf.d/10-monitor.conf

printf '%s\n' "Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "hr"
        Option "XkbOptions" "caps:escape"
EndSection" > /etc/X11/xorg.conf.d/00-keyboard.conf

printf '%s\n' "Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "ClickMethod" "clickfinger"
        Option "NaturalScrolling" "true"
        Option "ScrollMethod" "edge"
EndSection" > /etc/X11/xorg.conf.d/40-libinput.conf

printf '%s\n' "Do you wanna preload amdgpu with mkinitcpio.conf [y/n]: "
read preload_amdgpu
[[ $preload_amdgpu = "y" ]] && sed -i 's/MODULES=()/MODULES=(amdgpu)/' /etc/mkinitcpio.conf

printf '%s\n' "Setting up grub"
pacman --noconfirm -S grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

read -n 1 -s -p "To continue press any key"

if [[ $nvidia = "y" ]]; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 nmi_watchdog=0 zswap.enabled=0 nvidia-drm.modeset=1 rcutree.rcu_idle_gp_delay=1"/' /etc/default/grub
else
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 nmi_watchdog=0 zswap.enabled=0"/' /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Do you wanna disable sp5100_tco driver for amd to disable it's watchdog (Can help with shutdown errors) [y/n]: "
read sp5100_tco
if [[ $sp5100_tco = "y" ]]; then
    mkdir -p /etc/modprobe.d
    printf '%s\n' "blacklist sp5100_tco" > /etc/modprobe.d/sp5100_tco.conf
fi

printf '%s\n' "Do you wanna set up better swappiness settings [y/n]: "
read swap_settings
if [[ $swap_settings = "y" ]]; then
    mkdir -p /etc/sysctl.d
    printf '%s\n' "vm.swappiness = 10" > /etc/sysctl.d/99-swappiness.conf
    printf '%s\n' "vm.vfs_cache_pressure=50" > /etc/sysctl.d/99-vfs_cache_pressure.conf
fi

printf '%s\n' "Do you wanna disable network manager powersave [y/n]: "
read networkmanager_powersave
if [[ $networkmanager_powersave = "y" ]]; then 
    mkdir -p /etc/NetworkManager/conf.d
    printf '%s\n' "[connection]
    wifi.powersave = 2" > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
fi

printf '%s\n' "Have an ssd? Enable fstrim and make it run daily [y/n]: "
read ssd
if [[ $ssd = "y" ]]; then
    mkdir -v /etc/systemd/system/fstrim.timer.d
    touch /etc/systemd/system/fstrim.timer.d/override.conf
    printf '%s\n' "[Timer]
OnCalendar=
OnCalendar=daily" > /etc/systemd/system/fstrim.timer.d/override.conf
    systemctl enable fstrim.timer
fi

printf '%s\n' "Do you wanna enable zram (uses half the ram) [y/n]: "
read zram
if [[ $zram = "y" ]]; then
    pacman -S --noconfirm --needed zram-generator
    printf '%s\n' '[zram0]
zram-size = ram / 2' > /etc/systemd/zram-generator.conf
fi

printf '%s\n' "Do you wan't to disable hibernation [y/n]: "
read hibernation
[[ $hibernation = "y" ]] && systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

[[ $nvidia = "y" ]] && read -p "Do you wanna enable a fix for /oldroot/ during shutdown with nvidia? [y/n]: " oldroot_fix
if [[ $oldroot_fix = "y" ]]; then
    mkdir -p /usr/lib/systemd/system-shutdown
    printf '%s\n' "#!/bin/sh
# remove nvidia modules
/usr/bin/modprobe -r nvidia_drm nvidia_modeset nvidia_uvm && /usr/bin/modprobe -r nvidia" > /usr/lib/systemd/system-shutdown/nvidia.shutdown
    chmod +x /usr/lib/systemd/system-shutdown/nvidia.shutdown
fi

printf '%s\n' "Installing basic packages and enabling basic services"
pacman -S --noconfirm zsh p7zip unzip xclip base-devel \
    pacman-contrib wireless_tools man pcmanfm fzf git android-file-transfer \
    pipewire pipewire-pulse pipewire-alsa rtkit openssh android-udev \
    alsa-plugins alsa-tools alsa-utils pulsemixer pamixer \
    firefox playerctl lxsession bluez bluez-utils syncthing \
    keepassxc thunderbird shotgun xdotool bat acpid imagemagick\
    ufw hugo python-pygments python-gitpython udisks2 hacksaw \
    ccache smartmontools libreoffice-still aria2 ghostscript

systemctl enable rtkit-daemon.service
systemctl enable bluetooth.service
systemctl enable acpid.service

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Setting up makepkg.conf"
sed -i 's/-march=native/-march=x86-64 -mtune=generic/' /etc/makepkg.conf
sed -i 's/!ccache/ccache/g' /etc/makepkg.conf

printf '%s\n' "Set root password"
passwd

printf '%s\n' "Setting up user"

printf '%s\n' "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
printf '%s\n' "Enter Username: "
read username
useradd -m $username
passwd $username
usermod -a $username -G wheel
usermod -a $username -G network
usermod -a $username -G video
usermod -a $username -G input
usermod -a $username -G audio

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Setting up silent boot and autologin"
mkdir -p /etc/sysctl.d
printf '%s\n' "kernel.printk = 3 3 3 3" > /etc/sysctl.d/20-quiet-printk.conf
mkdir -p /etc/systemd/system/getty@tty1.service.d
printf '%s\n' "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --skip-login --nonewline --noissue --autologin $username --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/skip-prompt.conf

ai3_path=/home/$username/arch_install3.sh
sed '1,/^#part3$/d' arch_install2.sh > $ai3_path
chown $username:$username $ai3_path
chmod +x $ai3_path
su -c $ai3_path -s /bin/sh $username
rm -rf $ai3_path
printf '%s\n' "Pre-Installation Finish Reboot now"
exit

#part3
cd ~
printf '%s\n' "Setting up paru"
sudo pacman -S --noconfirm --needed go rust nodejs npm cmake git zig
git clone https://aur.archlinux.org/paru.git ~/paru
cd ~/paru
makepkg -si
read -n 1 -s -p "To continue press any key"
cd ~
rm -rf ~/paru

printf '%s\n' "Reloading systemd-resolved"
sudo systemctl restart systemd-resolved

printf '%s\n' "Setting up additional must have aur packages"
paru -S --needed --noconfirm brillo dmenu-bluetooth clipmenu-git xdg-ninja-git tutanota-desktop-bin ferdium-bin colorpicker yt-dlp downgrade dashbinsh

read -n 1 -s -p "To continue press any key"

printf '%s\n' "Getting my arch dotfiles"
mkdir -p ~/repos/dots
cd ~/repos/dots
git clone https://github.com/cronyakatsuki/arch-dots.git arch
read -n 1 -s -p "To continue press any key"
mkdir ~/.config
cd ~/repos/dots/arch
make

printf '%s\n' "Getting my general dotfiles"
mkdir -p ~/repos/dots
cd ~/repos/dots
git clone https://github.com/cronyakatsuki/general-dots.git general
read -n 1 -s -p "To continue press any key"
cd ~/repos/dots/general
make

printf '%s\n' "Getting my scripts"
mkdir -p ~/bin
cd ~/repos/dots
git clone https://github.com/cronyakatsuki/scripts.git ~/repos/dots/scripts
read -n 1 -s -p "To continue press any key"
ln -s $HOME/repos/dots/scripts $HOME/bin/misc

printf '%s\n' "Setting up neovim"
sudo pacman -S --noconfirm --needed neovim ripgrep
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

git clone https://github.com/cronyakatsuki/nvim-conf ~/.config/nvim
read -n 1 -s -p "To continue press any key"

printf '%s\n' "Setting up slock"
git clone https://github.com/cronyakatsuki/slock.git ~/repos/slock
cd ~/repos/slock
sudo make install clean
read -n 1 -s -p "To continue press any key"

printf '%s\n' "Setting up dmenu and dmenu scripts"
git clone https://github.com/cronyakatsuki/dmenu.git ~/repos/dmenu
cd ~/repos/dmenu
sudo make install clean
git clone https://github.com/cronyakatsuki/dmenu-scripts.git ~/repos/dmenu-scripts
ln -s $HOME/repos/dmenu-scripts $HOME/bin/dmenu
read -n 1 -s -p "To continue press any key"


printf '%s\n' "Do you wan't to setup gaming related packages, settings and optimizations? [y/n]"
read gaming
if [[ $gaming = "y" ]]; then
    if pacman -Qi nvidia-dkms > /dev/null; then
        printf '%s\n' "Installing nvidia drivers"
        sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
    fi

    if pacman -Qi xf86-video-amdgpu > /dev/null; then
        printf '%s\n' "Installing amdgpu drivers"
        sudo pacman -S --noconfirm --needed lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
    fi
    
    printf '%s\n' "Installing wine dependencies"
    sudo pacman -S --needed --noconfirm wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
    mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
    lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
    sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
    ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 vkd3d lib32-vkd3d \
    lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader

    printf '%s\n' "Installing gaming related software"
    paru -S --needed --noconfirm lib32-gamemode-git gamemode-git lib32-mangohud-git mangohud-common-git mangohud-git steam \
            lutris python-magic winetricks protontricks proton-ge-custom-bin \
            heroic-games-launcher-bin libstrangle-git --needed --noconfirm

    ln -s $HOME/repos/dots/.config/gamemode.ini $HOME/.config/gamemode.init
    ln -s $HOME/repos/dots/.config/Mangohud $HOME/.config/Mangohud

    printf '%s\n' "Setting up gamemode"
    sudo usermod -a `whoami` -G gamemode
    printf '%s\n' "@gamemode       -       nice    10" | sudo tee -a /etc/security/limits.conf
    printf '%s\n' '<driconf>
   <device>
       <application name="Default">
           <option name="vblank_mode" value="0" />
       </application>
   </device>
</driconf>' > /etc/drirc

    printf '%s\n' "Creating the default wine prefix folder"
    mkdir -p $HOME/.local/share/wineprefixes/default
fi

exit
