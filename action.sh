#!/bin/bash
set -ex
function cleanup() {
	df -h
	sudo swapoff -a
	sudo rm -f /swapfile
	sudo apt clean
	docker rmi $(docker image ls -aq)
	df -h
	sudo rm -rf /etc/apt/sources.list.d/* \
	/usr/share/dotnet \
	/usr/local/lib/android \
	/opt/hostedtoolcache/CodeQL \
	/usr/local/.ghcup \
	/usr/share/swift \
	/usr/local/lib/node_modules \
	/usr/local/share/powershell \
	/opt/ghc /usr/local/lib/heroku
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
	sudo apt update
	sudo apt install build-essential clang flex bison g++ gawk \
	gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
	python3-distutils python3-setuptools rsync swig unzip zlib1g-dev file wget
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
		git clone -b openwrt-23.05 https://github.com/openwrt/openwrt.git ./openwrt
		[ -f ./feeds.conf.default ] && cat ./feeds.conf.default >> ./openwrt/feeds.conf.default
	fi
	pushd openwrt
	
	./scripts/feeds update -a
	./scripts/feeds install -a
	rm -rf feeds/packages/lang/golang
    git clone https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang
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
