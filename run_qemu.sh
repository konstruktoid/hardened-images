#!/bin/bash
set -euo pipefail

OVMF_CODE="${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
OVMF_VARS_TEMPLATE="${OVMF_VARS_TEMPLATE:-/usr/share/OVMF/OVMF_VARS_4M.fd}"
SSH_PORT="${SSH_PORT:-2222}"
VM_MEMORY="${VM_MEMORY:-2048}"

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${BASE_DIR}/output"

QCOW2_IMAGE="${1:-}"

if [ -z "${QCOW2_IMAGE}" ]; then
  QCOW2_IMAGE="$(
    find "${OUTPUT_DIR}" -mindepth 2 -maxdepth 2 -name '*.qcow2' \
      -exec stat -c '%Y %n' {} + 2> /dev/null | sort -nr | head -1 | cut -d' ' -f2-
  )"
fi

if [ -z "${QCOW2_IMAGE}" ] || [ ! -f "${QCOW2_IMAGE}" ]; then
  printf 'No .qcow2 image found under %s. Build one with "bash build_box.sh" first, or pass a path as the first argument.\n' \
    "${OUTPUT_DIR}" >&2
  exit 1
fi

for file in "${OVMF_CODE}" "${OVMF_VARS_TEMPLATE}"; do
  [ -f "${file}" ] || {
    printf 'UEFI firmware not found: %s. Install the ovmf package or set OVMF_CODE and OVMF_VARS_TEMPLATE.\n' \
      "${file}" >&2
    exit 1
  }
done

VARS_DIR="$(mktemp --directory -t run-qemu.XXXXXX)"
trap 'rm -rf -- "${VARS_DIR}"' EXIT

VARS_FILE="${VARS_DIR}/OVMF_VARS.fd"
cp -- "${OVMF_VARS_TEMPLATE}" "${VARS_FILE}"

if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL_ARGS=(-machine "q35,accel=kvm" -cpu host)
else
  printf 'warning: /dev/kvm is not usable, falling back to software emulation.\n' >&2
  ACCEL_ARGS=(-machine q35 -cpu max)
fi

printf 'Booting %s\n' "${QCOW2_IMAGE}"
printf 'SSH once booted: ssh -p %s ubuntu@localhost\n' "${SSH_PORT}"

exec qemu-system-x86_64 \
  "${ACCEL_ARGS[@]}" \
  -m "${VM_MEMORY}" \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${VARS_FILE}" \
  -drive if=virtio,format=qcow2,file="${QCOW2_IMAGE}" \
  -netdev user,id=net0,hostfwd=tcp::"${SSH_PORT}"-:22 \
  -display none -serial mon:stdio \
  -device virtio-net-pci,netdev=net0
