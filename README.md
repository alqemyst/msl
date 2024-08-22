# macOS Subsystem for Linux

A small WSL2-like tool for running lightweight linux virtual machines on macOS. Code is based on Apple's Virtualization framework examples [https://developer.apple.com/documentation/virtualization]. Linux GUI is not supported.

```
msl --help

USAGE: msl [--cpu <cpu>] [--ram <ram>] [--kernel <kernel>] [--ramdisk <ramdisk>] [--disk <disk>] [--cmd <cmd>] [--mac <mac>] [--nvme]

OPTIONS:
  --cpu <cpu>             Number of CPUs VM will use (default: 1)
  --ram <ram>             RAM size in MB (default: 1024)
  --kernel <kernel>       Kernel image path (default: vmlinuz)
  --ramdisk <ramdisk>     Ramdisk image path (default: initrd)
  --disk <disk>           Root image path
  --cmd <cmd>             Kernel's command-line parameters (default: console=hvc0 rd.break=initqueue)
  --mac <mac>             Network device MAC address
  --nvme                  Create storage as NVME storage device
  -h, --help              Show help information.
```

### Preparing images
Thanks to [https://medium.com/@suyashmohan/setup-wsl-kinda-linux-box-on-macbook-m1-with-apple-virtualization-framework-ec2529f9797] author who made it easy. Let's start with Ubuntu example.

Download kernel and ramdisk images.
```sh
wget -O vmlinuz.gz https://cloud-images.ubuntu.com/releases/noble/release/unpacked/ubuntu-24.04-server-cloudimg-arm64-vmlinuz-generic
gunzip vmlinuz.gz

wget -O initrd https://cloud-images.ubuntu.com/releases/noble/release/unpacked/ubuntu-24.04-server-cloudimg-arm64-initrd-generic
```

Download rootfs image.
```sh
wget https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.tar.gz
tar xzf ubuntu-24.04-server-cloudimg-arm64.tar.gz
```

First we will boot initramfs only so we can set root password and network device to DHCP mode. If nvme flag was present block device will have different name (check /proc/partitions).
```sh
msl --disk noble-server-cloudimg-arm64.img --cmd "console=hvc0 rd.break=initqueue"
```

```sh
mkdir /mnt
mount /dev/vda /mnt
chroot /mnt

echo 'root:root' | chpasswd

cat <<EOF > /etc/netplan/01-dhcp.yaml
network:
  renderer: networkd
  ethernets:
    enp0s1:
      dhcp4: true
  version: 2
EOF
```

Now we can boot root image.
```sh
msl --disk noble-server-cloudimg-arm64.img --cmd "console=hvc0 rd.break=initqueue root=/dev/vda" --mac a8:e1:be:a5:4d:6f
```

### Resizing rootfs image
```sh
brew install qemu
```
```sh
qemu-img resize noble.img 16G
```


### DHCP server reservation
Modify /var/db/dhcpd_leases file, then start VM with custom MAC address.
```
{
  name=ubuntu
  ip_address=192.168.64.254
  hw_address=1,a8:e1:be:a5:4d:6f
  identifier=1,a8:e1:be:a5:4d:6f
  lease=0x66c43d2f
}
```
