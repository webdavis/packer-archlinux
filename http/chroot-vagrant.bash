#!/usr/bin/env bash

# Exit immediately on error, or when unset parameters are expanded.
set -eu

# This function kills the script when user interruptions are detected
interrupt()
{
    local code=$?
    trap '' EXIT
    exit $code
}

# Trap any user interruptions, such as Ctrl+c, calling interrupt() when they're caught.
trap interrupt INT
trap interrupt QUIT
trap interrupt TERM

# Configure the locale.
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
printf "%s\\n" 'LANG=en_US.UTF-8' > /etc/locale.conf

# Configure the user credentials.
user='vagrant'
printf "%s\\n%s" "$user" "$user" | passwd
useradd --create-home --user-group "$user"
printf "%s\\n%s" "$user" "$user" | passwd "$user"

# Set automatic authentication for any action requiring admin rights using Polkit.
cat <<EOF > /etc/polkit-1/rules.d/49-nopasswd_global.rules
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("${user}")) {
        return polkit.Result.YES;
    }
});
EOF
chmod 0440 /etc/polkit-1/rules.d/49-nopasswd_global.rules

# Add the user to the sudoers directory.
cat <<EOF > "/etc/sudoers.d/${user}"
Defaults:${user} !requiretty
${user} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "/etc/sudoers.d/${user}"

# Install the official Vagrant insecure key.
install --directory "--owner=${user}" "--group=${user}" --mode=0700 "/home/${user}/.ssh"
curl --output "/home/${user}/.ssh/authorized_keys" --location https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
chown "${user}:${user}" "/home/${user}/.ssh/authorized_keys"
chmod 0600 "/home/${user}/.ssh/authorized_keys"

# Disable the assignment of fixed interface names so that the unpredictable kernel names
# are used again, and can then be set as "eth0" by a Systemd service.
ln -s /dev/null /etc/systemd/network/99-default.link

# Create network service.
cat <<EOF > /etc/systemd/network/eth0.network
[Match]
Name=eth0

[Network]
DHCP=ipv4
EOF

# Setup pacman-init.service for clean pacman keyring initialization.
cat <<EOF > /etc/systemd/system/pacman-init.service
[Unit]
Description=Initializes Pacman keyring
Wants=haveged.service
After=haveged.service
ConditionFirstBoot=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/pacman-key --init
ExecStart=/usr/bin/pacman-key --populate archlinux

[Install]
WantedBy=multi-user.target
EOF

# Prevent reverse DNS lookups, which keeps things speedy.
sshd_config='/etc/ssh/sshd_config'
sed -i -e 's/^#\(UseDNS no\).*$/\1/' "$sshd_config"
# Host-based-authentication requires DNS.
echo 'HostBasedAuthentication no' >> "$sshd_config"

# Enable network services.
systemctl enable sshd.service
systemctl enable haveged.service
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systemctl enable pacman-init.service

# Check if this is an LTS installation, if it is then remove the standard linux kernel.
kernel='linux'
if pacman -Qi linux-lts &>/dev/null; then
    pacman --remove --nosave --unneeded --noconfirm linux
    kernel='linux-lts'
fi

# Provision the initramfs with lvm and the kernel.
sed -i -e 's/^\(HOOKS=(base udev autodetect modconf block \)\(filesystems keyboard fsck)\)/\1lvm2 \2/' /etc/mkinitcpio.conf
mkinitcpio --preset "$kernel"

# Link the host's lvm to the guests lvm to prevent "/dev/xxx not initialized in udev
# database" error when installing grub.
guestlvm='/run/lvm'
ln -s /hostlvm "$guestlvm"

# Install grub and build the boot-loader.
grubfile='/etc/default/grub'
sed -i -e 's/^\(GRUB_TIMEOUT\).*$/\1=1/' "$grubfile"
sed -i -e 's/^\(GRUB_PRELOAD_MODULES="part_gpt part_msdos\)".*$/\1 lvm"/' "$grubfile"
sed -i -e 's/^\(GRUB_CMDLINE_LINUX=\).*$/\1"root=\/dev\/volgroup\/root"/' "$grubfile"
grub-install "$device"
grub-mkconfig --output=/boot/grub/grub.cfg

rm "$guestlvm"
