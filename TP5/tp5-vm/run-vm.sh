#!/bin/bash
qemu-system-aarch64 \
  -machine virt -cpu cortex-a72 -smp 2 -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/AAVMF/AAVMF_CODE.fd \
  -drive if=pflash,format=raw,file=varstore.img \
  -drive if=virtio,format=qcow2,file=noble-server-cloudimg-arm64.img \
  -drive if=virtio,format=raw,file=seed.img \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::5555-:22,hostfwd=tcp::8080-:8080 \
  -nographic
