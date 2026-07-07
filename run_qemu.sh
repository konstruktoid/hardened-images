#!/bin/bash
set -euo pipefail

OUTPUT_DIR="$(pwd)/output"

QCOW2_IMAGE="${1:-}"

if [ -z "${QCOW2_IMAGE}" ]; then
  QCOW2_IMAGE="$(find ${OUTPUT_DIR} -mindepth 2 -maxdepth 2 -name '*.qcow2'   -exec stat -c '%W %n' {} \; | sort -nr | head -1 | cut -d' ' -f2-)"
fi

if [ -z "${QCOW2_IMAGE}" ] || [ ! -f "${QCOW2_IMAGE}" ]; then
  echo "No .qcow2 image found under ${OUTPUT_DIR}. Build one with 'bash build_box.sh' first, or pass a path as the first argument." >&2
  exit 1
fi

OVMF_CODE="${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
OVMF_VARS_TEMPLATE="${OVMF_VARS_TEMPLATE:-/usr/share/OVMF/OVMF_VARS_4M.fd}"
SSH_PORT="${SSH_PORT:-2222}"
VM_MEMORY="${VM_MEMORY:-2048}"

VARS_DIR="$(mktemp --directory -p /var/tmp run-qemu.XXXXXX)"
trap 'rm -rf "${VARS_DIR}"' EXIT

VARS_FILE="${VARS_DIR}/OVMF_VARS.fd"
cp "${OVMF_VARS_TEMPLATE}" "${VARS_FILE}"

ACCEL_ARGS=(-machine "q35,accel=kvm" -cpu host)
if [ ! -e /dev/kvm ]; then
  ACCEL_ARGS=(-machine q35 -cpu max)
fi

echo "Booting ${QCOW2_IMAGE}"
echo "SSH once booted: ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no ubuntu@localhost"

qemu-system-x86_64 \
  "${ACCEL_ARGS[@]}" \
  -m "${VM_MEMORY}" \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${VARS_FILE}" \
  -drive if=virtio,format=qcow2,file="${QCOW2_IMAGE}" \
  -netdev user,id=net0,hostfwd=tcp::"${SSH_PORT}"-:22 \
  -display none -serial mon:stdio \
  -device virtio-net-pci,netdev=net0
