#!/bin/sh

STAGE3=

partionning() {
sed -e 's/\s*\([+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda #` #########
o # Clear the in memory partition table
g # set GPT
n # new partition boot
1 # part number 1
  # default
+512M # 512 MB boot partition
n # new partition swap
2 #
 # default
+2GB # 2GB swap
t #
2 # default
19 # Linux swap
n # new partition root
 # default
 # default
 # default
w # write
EOF
}

mounting() {
mkfs.fat -F 32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ext4 /dev/sda3
mkdir /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
cd /mnt/gentoo ;}

stage3() {
wget $STAGE3
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner ;}

#MAKECONF + setup gentoo repo x=??? lspcu
make_conf() { # march=native
nano -w /mnt/gentoo/etc/portage/make.conf # manual interactions
#echo -e 'MAKEOPTS="-jx -lx"' >> /mnt/gentoo/etc/portage/make.conf
#echo -e 'PORTAGE_NICENESS="1"' >> /mnt/gentoo/etc/portage/make.conf
#echo -e 'EMERGE_DEFAULT_OPTS="--autounmask-write --jobs=x --load-average=x with-bdeps y --complete-graph y"' >> /mnt/gentoo/etc/portage/make.conf
#echo -e 'FEATURES="candy fixlafiles unmerge-orphans parallel-install"' >> /mnt/gentoo/etc/portage/make.conf
#echo -e 'ACCEPT_KEYWORDS="~amd64"' >> /mnt/gentoo/etc/portage/make.conf
#echo -e 'ACCEPT_LICENSE="*"' >>  /mnt/gentoo/etc/portage/make.conf
#echo -e 'USE="-wayland -kde -gnome -consolekit -systemd -pulseaudio alsa elogind dbus X"'
#echo -e 'INPUT_DEVICES="libinput synaptics"'
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf
}

newroot() {
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
chroot /mnt/gentoo /bin/bash
source /etc/profile
mount /dev/sda1 /boot ;}

portage_setup() {
emerge-webrsync
emerge --sync
emerge -1 sys-apps/portage
eselect profile set 3
emerge -avuND @world ;}

locale_gen() {
echo "US/Eastern" > /etc/timezone
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set 3
source /etc/profile ;}

# x ??
kernel_setup() {
emerge pciutils gentoo-sources
cd /usr/src/linux
make menuconfig
make -jx && make modules_install install
emerge linux-firmware ;}

fstab_setup() {
blkid | awk '{print $2}'  >> /etc/fstab
nano -w /etc/fstab # manual interaction
;}

net_setup() {
echo 'hostname="Gentoo"' >> /etc/conf.d/hostname
emerge --noreplace netifrc
echo 'config_eth0="dhcp"' >> /etc/conf.d/net
cd /etc/init.d
ln -s ne/t.lo net.eth0
rc-update add net.eth0 default
echo "127.0.1.1		Gentoo" >> /etc/hosts ;}

efi_setup() {
emerge sys-boot/efibootmgr
cd /boot
mkdir -p /boot/efi/boot
cp /boot/vmlinuz-`uname -r` /boot/efi/boot/bootx64.efi
efibootmgr --create --disk /dev/sda --part 1 --label "Gentoo" --loader "\efi\boot\bootx64.efi" ;}


user_setup() {
emerge app-shells/zsh app-shells/gentoo-zsh-completions app-shells/zsh-completion app-shells/zsh-syntax-highlighting
useradd -m -G users,wheel,audio,video,usb -s /bin/zsh nic
passwd nic ;} # manual interaction

ebuild_repo() {
cd /var/db
mkdir -p repos/custom/{metadata,profiles}
chown -R portage:portage repos/custom
echo "custom" >> profiles/repo_name
echo -e '"masters=gentoo"\n"auto-sync-false"' >> metadata/layout.conf
echo -e '[custom]\nlocation = /var/db/repos/custom' >> /etc/portage/repos.conf/custom.conf
}


desktop_setup() {
emerge x11-base/xorg-driver x11-base/xorg-server
echo 'VIDEO_CARDS="nouveau"' >> /mnt/gentoo/etc/portage/make.conf
emerge media-libs/mesa x11-apps/mesa-progs
emerge -avuND @world
emerge app-portage/eix app-portage/repoman
echo "x11-wm/dwm savedconfig" >> /etc/portage/package.use/custom
echo "x11-terms/st savedconfig" >> /etc/portage/package.use/custom
echo "x11-misc/dmenu savedconfig" >> /etc/portage/package.use/custom
emerge x11-wm/dwm x11-terms/st x11-misc/dmenu
echo "media-video/ffmpeg mp3" >> /etc/portage/package.use/custom
emerge net-misc/youtube-dl media-video/ffmpeg
emerge app-text/zathura app-text/zathura-pdf-poppler
emerge media-sound/alsa-utils
echo "x11-misc/xwallpaper jpeg png" >> /etc/portage/package.use/custom
echo "media-gfx/sxiv gif" >> /etc/portage/package.use/custom
emerge x11-misc/slop media-gfx/maim media-gfx/sxiv x11-misc/xwallpaper x11-misc/dunst x11-misc/xdg-utils
emerge dev-vcs/git app-editors/neovim x11-misc/xclip x11-misc/xdotool x11-apps/setxkbmap x11-apps/xmodmap


dotfiles_setup() {
su - nic
cd ~/
git init --bare $HOME/.cfg
alias cfg='/usr/bin/git --git-dir=$HOME/.cfg --work-tree=$HOME'
cfg config --local status.showUntrackedFiles no
cd /tmp
git clone https://github.com/Baldr333/dotfiles.git
cd dotfiles
cp .config $HOME/ && cp .local $HOME/
cp .xprofile $HOME/ && cp .xprofile $HOME/

# Luke ST
# finish desktop config transmission rss etc...
# verify cd logic...


# TO DO
#automate manual interaction
#add lf + eselect librewolf repo
# htop + patch

# Install Start

partionning || #error msg

mounting || #error msg

stage3 ||

make_conf ||

newroot ||

portage_setup ||

locale_gen ||

kernel_setup ||

fstab_setup ||

net_setup ||

efi_setup ||

user_setup ||

ebuild_repo ||

desktop_setup ||

dotfiles_setup ||

#exit
#reboot
