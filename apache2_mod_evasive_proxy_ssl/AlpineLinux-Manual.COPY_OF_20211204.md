# Alpine installation quick-instructions - COPY_OF_20211204.md)

## Basic Installation onto a x64_86 Virtual Machine
Alpine Linux is very limited in terms of hardware- and bare-metal-support. Para-Virtual Disk and Network adapters are known to work, other hardware is not known.

### Create Virtual Machine/Appliance
- System: 1CPU and 384MB is recommended for installation (Alpine will otherwise assign an insane amount of swap during installation).
- Network: vmxnet3 is known to work, intel pro/1000 should. 100mbit or dedicated hardware is commonly _not_ supported by alpine-linux.
- without any payload, 200MB is the known minimum disksize.

### Install Virtual Machine/Appliance
- configure your system to boot [a recent alpine-virt ISO](https://dl-cdn.alpinelinux.org/alpine/v3.14/releases/x86_64/alpine-virt-3.14.2-x86_64.iso)
- Upon life-cd-boot, login as _root_ without password
- Verify the NIC is recognized `ifconfig -a` <- lookout for _eth0_.
- Verify the DISK is recognized `cat /proc/partitions` <- lookout for _sda_.
- run the interactive installer `setup-alpine`. Questions below not specific answered, just enter/skip/adjust-at-will.
- hint: when using fixed ip addresses, nameservers must be space seprareted

(alpine-setup)
- keyboard and variant, both times **_ch_**.
- timezone **_Europe_** , sub-timezone **_Zurich_**.
- disk to use **_sda_**, how to use as **_sys_**.

(alpine-setup finished)
- eject the ISO/CD and restart using `reboot`.

### enable SSH!
After booting the local-disk installed system, enable root-ssh here. (no idea what alpine's concept supposed to be)

- using the KVM console, login as root.
- (optionally install the widely favored editor `apk add nano`)
- enable ssh-root-access with setting _PermitRootLogin yes_ in `vi /etc/ssh/sshd_config`. 
  - edit the line to be `PermitRootLogin yes`
- `reboot` or `rc-service sshd restart` to apply root-login for ssh.
> Note: editing the _/etc/ssh/sshd_config_ could also be achieved before the reboot after alpine-setup ...
> ```bash
> mount /dev/sda3 /mnt
> vi /mnt/etc/ssh/sshd_config
> # PermitRootLogin yes 
> reboot
> ```
---

## tweaks
### remove annoying ttyS0 getty
```bash
sed -i 's/^ttyS0/#&/' /etc/inittab
```

### install the [open-vm-tools](https://wiki.alpinelinux.org/wiki/Open-vm-tools)
```bash
# enable 'community' repository
sed -i '/v3.*\/community/s/^#//' /etc/apk/repositories

# install openvm-toolsapk add open-vm-tools
apk add open-vm-tools

# start and mark for boot
rc-service open-vm-tools start
rc-update add open-vm-tools boot
```

### add some shell nice-ness
```bash
apk add bash mc 
wget http://gitlab.gebaschtel.ch:616/Pub/NetBoot/-/raw/master/Dist/Linux/rh.KickStart.functions.sh
bash -c "source rh.KickStart.functions.sh; declare -f util_colorcode" > /etc/profile.d/gbl.sh
echo "util_colorcode cold" >> /etc/profile.d/gbl.sh
echo "alias ll='ls -lah'" >> /etc/profile.d/gbl.sh
chmod +x /etc/profile.d/gbl.sh
rm rh.KickStart.functions.sh

```

### disable IPv6
```bash
cat <<EOF > /etc/sysctl.d/disable_ipv6.conf
#Force IPv6 off
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
#reboot
```

--- 
## install additional software

### install docker and compose on alpine
```
apk add docker docker-compose
rc-update add docker boot
service docker start
```

---
## management topics - if required

### set a fixed IP
- edit your `/etc/resolv.conf` and add some _nameserver 8.8.4.4_
- edit your `/etc/resolv.conf` and a line like _search what.ever_ (important)
- edit your `/etc/network/interfaces`, add after the _auto eth0_ line
```
iface eth0 inet static
        address 192.168.1.150
        netmask 255.255.255.0
        gateway 192.168.1.1
```

