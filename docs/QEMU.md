## QEMU

### Prerequisite
* MacOS >= Big Sur
* vde\_vmnet

#### Install vde\_vmnet
1. Install [https://github.com/lima-vm/vde\_vmnet](https://github.com/lima-vm/vde_vmnet).
2. Modify `/Library/LaunchDaemons/io.github.virtualsquare.vde-2.vde_switch.plist` and `/Library/LaunchDaemons/io.github.lima-vm.vde_vmnet.plist` to use the correct program path.
3. Start the vde\_switch and vde\_vmnet.
    * `sudo launchctl load -w /Library/LaunchDaemons/io.github.virtualsquare.vde-2.vde_switch.plist`
    * `sudo Launchctl load -w /Library/LaunchDaemons/io.github.lima-vm.vde_vmnet.plist`

### QEMU scripts for aarch64

#### Download QEMU EFI
```shell
wget https://releases.linaro.org/components/kernel/uefi-linaro/latest/release/qemu64/QEMU_EFI.fd
```

#### Create image
```
qemu-img create -f raw -o preallocation=full ubuntu.img 40G
```

#### setup.sh
```shell
#!/usr/bin/env bash

if ! pgrep vde_vmnet > /dev/null; then
  echo "Start vde_vmnet"
  sudo launchctl load -w /Library/LaunchDaemons/io.github.lima-vm.vde_vmnet.plist
fi

### generate random mac address
### python -c "import random; print(':'.join(map(lambda x: '%02x' % random.randint(0x00, 0xff), range(6))))"

MAC_ADDRESS='80:05:7b:58:82:7e'

qemu-system-aarch64 \
  -machine virt,accel=hvf,highmem=off \
  -cpu cortex-a72 \
  -smp 8 \
  -m 8g \
  -device virtio-blk-pci,drive=system \
  -drive id=system,if=none,cache=none,format=raw,file=./ubuntu.img \
  -nic vde,model=virtio-net-pci,mac="${MAC_ADDRESS}",sock=/var/run/vde.ctl \
  -cdrom <path to ubuntu arm64 iso> \
  -nographic \
  -bios QEMU_EFI.fd
```

#### boot.sh
```shell
#!/usr/bin/env bash

if ! pgrep vde_vmnet > /dev/null; then
  echo "Start vde_vmnet"
  sudo launchctl load -w /Library/LaunchDaemons/io.github.lima-vm.vde_vmnet.plist
fi

### generate random mac address
### python -c "import random; print(':'.join(map(lambda x: '%02x' % random.randint(0x00, 0xff), range(6))))"

MAC_ADDRESS='80:05:7b:58:82:7e'

qemu-system-aarch64 \
  -machine virt,accel=hvf,highmem=off \
  -cpu cortex-a72 \
  -smp 8 \
  -m 8g \
  -device virtio-blk-pci,drive=system \
  -drive id=system,if=none,cache=none,format=raw,file=./ubuntu.img \
  -nic vde,model=virtio-net-pci,mac="${MAC_ADDRESS}",sock=/var/run/vde.ctl \
  -nographic \
  -bios QEMU_EFI.fd
```

