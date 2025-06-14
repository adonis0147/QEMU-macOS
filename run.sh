#!/usr/bin/env bash

set -e

SCRIPT_PATH="$(
	cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
	pwd
)"
declare -r SCRIPT_PATH

declare -r USER='adonis'
declare -r HOST='192.168.105.2'

function clean {
	local origin_image="${SCRIPT_PATH}/ubuntu.qcow2"

	rm -f "${origin_image}"
}

function install_socket_vmnet() {
	if ! command -v socket_vmnet_client &>/dev/null; then
		brew install socket_vmnet
		sudo brew services start socket_vmnet
	fi
}

function get_cloud_image() {
	local arch="${1}"
	local url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-${arch}.img"

	echo "${url}"
}

function download_cloud_image() {
	local arch
	arch="$(uname -m)"
	arch="${arch/x86_64/amd64}"

	local url
	url="$(get_cloud_image "${arch}")"

	mkdir -p cloud_image
	pushd cloud_image &>/dev/null

	if [[ ! -f "$(basename "${url}")" ]]; then
		curl -LO "${url}"
	fi

	popd &>/dev/null
}

function gen_iso() {
	rm -f "${SCRIPT_PATH}/cloud-init.iso"

	"${SCRIPT_PATH}/cloud-localds" cloud-init.iso cloud-init/user-data.yaml cloud-init/meta-data.yaml
}

function create_disks() {
	local arch
	arch="$(uname -m)"
	arch="${arch/x86_64/amd64}"

	local system_disk_size="${1}"
	local data_disk_size="${2}"
	local cloud_image
	cloud_image="$(basename "$(get_cloud_image "${arch}")")"

	if [[ -z "$(find . -mindepth 1 -maxdepth 1 -name '*.img')" ]]; then
		local origin_image="${SCRIPT_PATH}/ubuntu.qcow2"
		cp "cloud_image/${cloud_image}" "${origin_image}"
		trap clean EXIT

		qemu-img resize "${origin_image}" "${system_disk_size}"
		qemu-img convert -f qcow2 -O raw -o preallocation=full "${origin_image}" ubuntu.img
		qemu-img create -f raw -o preallocation=full data.img "${data_disk_size}"

		rm "${origin_image}"
	fi
}

function run() {
	local arch
	arch="$(uname -m)"
	arch="${arch/arm64/aarch64}"

	local disks=(
		'ubuntu.img'
		'data.img'
	)
	for disk in "${disks[@]}"; do
		if [[ -n "$(lsof "${disk}")" ]]; then
			ssh "${USER}"@"${HOST}"
			return
		fi
	done

	machine='virt'
	cpu='host'
	if [[ "${arch}" == 'x86_64' ]]; then
		machine='q35'
		cpu="${cpu},-pdpe1gb"
	fi

	socket_vmnet_client "$(brew --prefix)/var/run/socket_vmnet" \
		"qemu-system-${arch}" \
		-machine "${machine}",accel=hvf \
		-cpu "${cpu}" \
		-smp 6 \
		-m 12G \
		-device virtio-net-pci,netdev=net0 -netdev socket,id=net0,fd=3 \
		-cdrom cloud-init.iso \
		-drive if=pflash,format=raw,readonly=on,file="$(brew --prefix)/opt/qemu/share/qemu/edk2-${arch}-code.fd" \
		-drive if=virtio,format=raw,file=ubuntu.img \
		-drive if=virtio,format=raw,file=data.img \
		-nographic "${@}"
}

function main() {
	pushd "${SCRIPT_PATH}" &>/dev/null

	if [[ ! -d "$(brew --prefix)/opt/socket_vmnet" ]] || ! command -v socket_vmnet_client &>/dev/null; then
		PATH="$(brew --prefix)/opt/socket_vmnet/bin:${PATH}"
		export PATH
	fi

	install_socket_vmnet
	download_cloud_image
	gen_iso
	create_disks '32G' '64G'
	run "${@}"

	popd &>/dev/null
}

main "${@}"
