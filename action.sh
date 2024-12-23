#!/bin/bash
set -ex
function cleanup() {
	if [ -f /swapfile ]; then
		sudo swapoff /swapfile
		sudo rm -rf /swapfile
	fi
	sudo rm -rf /etc/apt/sources.list.d/* \
	/usr/share/dotnet \
	/usr/local/lib/android \
	/opt/hostedtoolcache/CodeQL \
	/usr/local/.ghcup \
	/usr/share/swift \
	/usr/local/lib/node_modules \
	/usr/local/share/powershell \
	/opt/ghc /usr/local/lib/heroku || true
	command -v docker && docker rmi $(docker images -q)
	sudo apt-get -y purge \
		azure-cli* \
		ghc* \
		zulu* \
		hhvm* \
		llvm* \
		firefox* \
		google* \
		dotnet* \
		openjdk* \
		mysql* \
		php* || true
	sudo apt autoremove --purge -y || true
	df -h
}

function init() {
	[ -f sources.list ] && (
		sudo cp -rf sources.list /etc/apt/sources.list
		sudo rm -rf /etc/apt/sources.list.d/* /var/lib/apt/lists/*
		sudo apt-get clean all
	)
	sudo apt update -y
	sudo apt full-upgrade -y
	sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
	bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gettext gcc-multilib g++-multilib \
	git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev \
	libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libncurses-dev libpython3-dev libreadline-dev \
	libssl-dev libtool llvm lrzsz genisoimage msmtp ninja-build p7zip p7zip-full patch pkgconf python3 \
	python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion swig texinfo \
	uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev
	sudo timedatectl set-timezone Asia/Shanghai
	git config --global user.name "GitHub Action"
	git config --global user.email "action@github.com"
}

function build() {
	if [ -d openwrt ]; then
		pushd openwrt
		git pull
		popd
	else
		git clone https://github.com/coolsnowwolf/lede.git ./openwrt
		[ -f ./feeds.conf.default ] && cat ./feeds.conf.default >> ./openwrt/feeds.conf.default
	fi
	pushd openwrt
	
	./scripts/feeds update -a
	./scripts/feeds install -a
	[ -d ../patches ] && git am -3 ../patches/*.patch
	[ -d ../files ] && cp -fr ../files ./files
	[ -f ../config ] && cp -fr ../config ./.config
	make defconfig
	make download -j$(nproc)
	make -j$(nproc)
	popd
}

function artifact() {
	ls -a
	mkdir -p ./openwrt-r4s-squashfs-img
	cp ./openwrt/bin/targets/rockchip/armv8/openwrt-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz ./openwrt-r4s-squashfs-img
	cp ./openwrt/bin/targets/rockchip/armv8/config.buildinfo ./openwrt-r4s-squashfs-img
	zip -r openwrt-r4s-squashfs-img.zip ./openwrt-r4s-squashfs-img

	mkdir -p ./openwrt-r4s-ext4-img
	cp ./openwrt/bin/targets/rockchip/armv8/openwrt-rockchip-armv8-friendlyarm_nanopi-r4s-ext4-sysupgrade.img.gz ./openwrt-r4s-ext4-img
	cp ./openwrt/bin/targets/rockchip/armv8/config.buildinfo ./openwrt-r4s-ext4-img
	zip -r openwrt-r4s-ext4-img.zip ./openwrt-r4s-ext4-img
}

function auto() {
	cleanup
	init
	build
	artifact
}

$@
