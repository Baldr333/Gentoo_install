#!/bin/sh

STAGE3=https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/20210611T113421Z/hardened/stage3-amd64-hardened-20210611T113421Z.tar.xz

partionning() {
sed -e 's/\s*\([+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
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

make_conf() {
echo 'COMMON_FLAGS="-march=native -02 -pipe"' > /mnt/gentoo/etc/portage/make.conf
echo 'CFLAGS="{COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
echo 'CXXFLAGS="{COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
echo 'FCFLAGS="{COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
echo 'FFLAGS="{COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
echo 'MAKEOPTS="-jx -lx"' >> /mnt/gentoo/etc/portage/make.conf     ###### x ?
echo 'PORTAGE_NICENESS="1"' >> /mnt/gentoo/etc/portage/make.conf
echo 'EMERGE_DEFAULT_OPTS="--autounmask-write --jobs=x --load-average=x with-bdeps y --complete-graph y"' >> /mnt/gentoo/etc/portage/make.conf
echo 'FEATURES="candy fixlafiles unmerge-orphans parallel-install"' >> /mnt/gentoo/etc/portage/make.conf
echo 'ACCEPT_KEYWORDS="~amd64"' >> /mnt/gentoo/etc/portage/make.conf
echo 'ACCEPT_LICENSE="*"' >>  /mnt/gentoo/etc/portage/make.conf
echo 'USE="-wayland -kde -gnome -qt -consolekit -systemd -pulseaudio alsa elogind dbus X"' >>  /mnt/gentoo/etc/portage/make.conf
echo 'INPUT_DEVICES="libinput synaptics"' >>  /mnt/gentoo/etc/portage/make.conf
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf ;}

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
make menuconfig # manual interaction
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

ebuilds() {
cd /var/db
mkdir -p repos/custom/{metadata,profiles}
chown -R portage:portage repos/custom
echo "custom" >> profiles/repo_name
echo -e '"masters=gentoo"\n"auto-sync-false"' >> metadata/layout.conf
echo -e '[custom]\nlocation = /var/db/repos/custom' >> /etc/portage/repos.conf/custom.conf
mkdir -p /var/db/repos/custom/app-misc/lf
chown -R portage:portage app-misc
cd app-misc/lf/ && wget gpo.zugaina.org/AJAX/Ebuild/53399251 -O lf-9999.ebuild
repoman manifest && chown portage:portage lf-9999.ebuild
;}


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
emerge dev-vcs/git app-editors/neovim x11-misc/xclip x11-misc/xdotool x11-apps/setxkbmap x11-apps/xmodmap app-eselect/eselect-repository
eselect repository add librewolf git https://gitlab.com/librewolf-community/browser/gentoo.git
emaint -r librewolf sync
echo "app-misc/lf **" >> /etc/portage/package.accept_keywords/custom
emerge lf
;}


#dotfiles_setup() {
#su - nic
#cd ~/
#git init --bare $HOME/.cfg
#alias cfg='/usr/bin/git --git-dir=$HOME/.cfg --work-tree=$HOME'
#cfg config --local status.showUntrackedFiles no
#cd /tmp
#git clone https://github.com/Baldr333/dotfiles.git
#cd dotfiles
#cp * $HOME

# Install Start

partionning || echo "error step 1"

mounting || echo "error step 2"

stage3 || echo "error step 3"

make_conf || echo "error step 4"

newroot || echo "error step 5"

portage_setup || echo "error step 6"

locale_gen || echo "error step 7"

kernel_setup || echo "error step 8"

fstab_setup || echo "error step 9"

net_setup || echo "error step 10"

efi_setup || echo "error step 11"

user_setup || echo "error step 12"

ebuilds || echo "error step 13"

desktop_setup || echo "error step 14"

#dotfiles_setup || echo "error step 15"

exit
reboot
