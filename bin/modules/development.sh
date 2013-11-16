NAME="buildard buildem installem resetgps2"

buildard_description="Builds Arduino analog data collector images"
buildard_start() {
	unset CFLAGS
	unset CXXFLAGS

	for BOARD in ${BOARDS}; do
		echo -e "	${STAR} Building Arduino software (em-adc.pde) for ${BOARD} ... " &&
		rm -rf /tmp/arduino && mkdir /tmp/arduino &&
		cp /opt/em/arduino/em-adc.pde /tmp/arduino/ &&
		echo "BOARD_TAG = ${BOARD}" >> /tmp/arduino/Makefile &&
		echo "ARDUINO_DIR = /opt/arduino" >> /tmp/arduino/Makefile &&
		echo "ARDMK_DIR = /opt/arduino" >> /tmp/arduino/Makefile &&
		echo "AVR_TOOLS_DIR = /opt/arduino/avr-tools" >> /tmp/arduino/Makefile &&
		echo "AVRDUDE = /usr/bin/avrdude" >> /tmp/arduino/Makefile &&
		echo "AVRDUDE_CONF = /etc/avrdude.conf" >> /tmp/arduino/Makefile &&
		echo "CFLAGS = " >> /tmp/arduino/Makefile &&
		echo "CXXFLAGS = " >> /tmp/arduino/Makefile &&
		echo "include /opt/arduino/Arduino.mk" >> /tmp/arduino/Makefile &&
		cd /tmp/arduino &&
		make > /dev/null &&
		cp /tmp/arduino/build-${BOARD}/arduino.hex /opt/em/arduino/${BOARD}.hex
	done

	rm -rf /tmp/arduino
}

installem_description="Installs EM software on a blank OS disk"
installem_usage="
Usage:\t${bldwht}em installem <device> <version>\t\t${txtrst}(where <device> is the OS SSD, <version> is an EM release)\n
\tex: em installem /dev/sdb 2.0.0"
installem_start() {
	if [ ${#} -ne 2 ]; then
		ls -l /dev/sd*
		ls -l /opt/em/images/em-*
		echo
		echo -e ${installem_usage}
		exit 1
	fi

	if [ ${UID} -ne 0 ]; then
		echo -e "${bldred}You must be root to use this command${txtrst}"
		exit 1
	fi

	IMAGE="/opt/em/images/em-${2}"
	if [ ! -f ${IMAGE} ]; then
		echo -e "${bldred}Image ${bldwht}${IMAGE}${bldred} can't be found${txtrst}"
		exit 1
	fi

	RELEASE=${2}
	DEVICE="/dev/`basename ${1}`"

	if ! lsblk ${DEVICE} > /dev/null 2>&1; then
		echo -e "${bldred}${DEVICE} is not a block device${txtrst}"
		exit 1
	fi

	echo -e "${bldred}Beginning operations on ${DEVICE} in 3 seconds ... hit CTRL+C to stop me${txtrst}"
	sleep 3

	echo -ne "	${STAR} Unmounting any mounted partitions on ${DEVICE} ... " &&
	umount -f ${DEVICE}* > /dev/null 2>&1
	echo -e ${OK}

	echo -ne "	${STAR} Clearing partition table ... " &&
	dd if=/dev/zero of=${DEVICE} bs=4096 count=1 > /dev/null 2>&1 &&
	echo -e ${OK}

	echo -ne "	${STAR} Creating new partitions ... " &&
	echo -e "2048,8388608,L,*\n8390656,,L" | sfdisk -uS -qL ${DEVICE} > /dev/null 2>&1 &&
	echo -e ${OK}
	
	echo -ne "	${STAR} Formatting /boot ... " &&
	mkfs.ext4 -q -L BOOT -O none,dir_index,extent,filetype,flex_bg,has_journal,sparse_super,uninit_bg,large_file -E discard -b 4096 -I 256 -i 65536 -m 1 ${DEVICE}1 &&
	echo -e ${OK}

	echo -ne "	${STAR} Formatting /var ... " &&
	mkfs.ext4 -q -L VAR -O none,dir_index,extent,filetype,flex_bg,has_journal,sparse_super,uninit_bg,large_file -E discard -b 4096 -I 256 -i 16384 -m 1 ${DEVICE}2 &&
	echo -e ${OK}

	echo -ne "	${STAR} Mounting new /boot and /var at /mnt/install ... " &&
	umount -f /mnt/install > /dev/null 2>&1
	rm -rf /mnt/install
	mkdir -p /mnt/install/boot /mnt/install/var
	mount ${DEVICE}1 /mnt/install/boot
	mount ${DEVICE}2 /mnt/install/var
	echo -e ${OK}

	echo -ne "	${STAR} Creating skeleton structure and swap file ... " &&
	cd /mnt/install
	mkdir -p boot/grub var/cache/fontconfig var/cache/ldconfig var/em/data/archived var/em/data/reports var/em/data/screenshots var/em/data/video var/elog var/lib/dbus var/lib/hwclock var/lib/sshd var/lib/systemd/catalog var/lib/xkb var/log/journal
	chmod 750 var/cache/ldconfig
	ln -s /run/lock var/lock
	ln -s /run var/run
	ln -s /tmp var/tmp
	dd if=/dev/zero of=/mnt/install/var/swapfile bs=256K count=2048 > /dev/null 2>&1
	chmod 0600 /mnt/install/var/swapfile
	mkswap /mnt/install/var/swapfile > /dev/null
	cp /opt/em/src/em.conf /opt/em/src/encoding.conf /mnt/install/var/em/

	dbus-uuidgen --ensure=/mnt/install/var/lib/dbus/machine-id
	journalctl --update-catalog
	cp --preserve=all /var/lib/systemd/catalog/database /mnt/install/var/lib/systemd/catalog/
	#chown -R ecotrust:ecotrust var/em
	echo -e ${OK}

	echo -ne "	${STAR} Installing ${IMAGE} ... " &&
	cp ${IMAGE} /mnt/install/boot/
	echo -e ${OK}

	echo -ne "	${STAR} Installing GRUB ... " &&
	grub-install --boot-directory=/mnt/install/boot ${DEVICE} > /dev/null
	cp /opt/em/src/grub.cfg /mnt/install/boot/grub/
	echo "menuentry 'EM ${RELEASE}' --class electronic --class gnu-linux --class gnu --class os --unrestricted \$menuentry_id_option 'em-${RELEASE}' {" >> /mnt/install/boot/grub/grub.cfg
	echo "savedefault" >> /mnt/install/boot/grub/grub.cfg
	echo "insmod gzio" >> /mnt/install/boot/grub/grub.cfg
	echo "insmod part_msdos" >> /mnt/install/boot/grub/grub.cfg
	echo "insmod ext2" >> /mnt/install/boot/grub/grub.cfg
	echo "set root=(hd0,msdos1)" >> /mnt/install/boot/grub/grub.cfg
	echo "echo 'Loading EM software v${RELEASE} ...'" >> /mnt/install/boot/grub/grub.cfg
	echo "linux /em-${RELEASE} ro quiet" >> /mnt/install/boot/grub/grub.cfg
	echo "}" >> /mnt/install/boot/grub/grub.cfg
	echo >> /mnt/install/boot/grub/grub.cfg
	echo -e ${OK}

	echo -ne "	${STAR} Editing /mnt/install/var/em/em.conf ... " &&
	vim /mnt/install/var/em/em.conf
	echo -e ${OK}

	echo -ne "	${STAR} Unmounting /mnt/install/boot and /mnt/install/var ... " &&
	sync
	umount /mnt/install/var
	umount /mnt/install/boot
	echo -e ${OK}

	echo
	echo -e "${txtgrn}Finished!"
}

buildem_description="Builds EM image file"
buildem_usage="
Usage:\t${bldwht}em buildem <release version>\t\t${txtrst}(where <release version> is a number)\n
\tex: em buildem 2.0.1"
buildem_start() {
        if [ ${#} -ne 1 ]; then
                echo
                echo -e ${buildem_usage}
                exit 1
        fi

        if [ ${UID} -ne 0 ]; then
                echo -e "${bldred}You must be root to use this command${txtrst}"
                exit 1
        fi

	echo -ne "	${STAR} Building em-rec ... " &&
	cd /opt/em/src/rec && make > /dev/null
	make > /dev/null
	echo -e ${OK}
 
	#/opt/em/bin/em buildard

	VER=${1}
	DEST=/usr/src/em-${1}

	echo -ne "	${STAR} Preparing image root at ${DEST} ... " &&
	rm -rf ${DEST} && mkdir -p ${DEST}
	cd ${DEST}
	echo -n ${VER} > ${DEST}/em-release
	mkdir -p boot dev mnt/data proc root run sys tmp var
	echo -e ${OK}

	echo -ne "	${STAR} Copying files ... " &&
	for FILE in `cat /opt/em/src/files.lst`; do cp -r --parents --no-dereference --preserve=all /$FILE ${DEST}/; done
	cp /opt/em/src/fstab /opt/em/src/resolv.conf ${DEST}/etc/
	ln -s /sbin/init ${DEST}/init
	echo -e ${OK}

	echo -ne "	${STAR} Stripping executables ... " &&
	find ${DEST} | xargs file | grep "executable" | grep ELF | cut -f 1 -d : | xargs -r strip --strip-unneeded
	echo -e ${OK}

	echo -ne "	${STAR} Stripping libraries ... " &&
	find ${DEST} | xargs file | grep "shared object" | grep ELF | cut -f 1 -d : | xargs -r strip --strip-unneeded
	echo -e ${OK}

	echo -ne "	${STAR} Stripping other archives ... " &&
	find ${DEST} | xargs file | grep "current ar archive" | cut -f 1 -d : | xargs -r strip --strip-unneeded
	echo -e ${OK}

	echo -ne "	${STAR} Running ldconfig ... " &&
	ldconfig -r ${DEST}
	echo -e ${OK}

	echo -e "	${STAR} Building Linux kernel, modules, and updating ${DEST} ... " && 
	cp /opt/em/src/config-${VER} /usr/src/linux/.config
	cd /usr/src/linux
	rm -f usr/initramfs_data.cpio*
	echo CONFIG_INITRAMFS_SOURCE=\"\" >> /usr/src/linux/.config
	make -j4 bzImage > /dev/null
	make -j4 modules > /dev/null && make modules_install > /dev/null
	cd /usr/src/fanout
	make clean > /dev/null 2>&1
	make > /dev/null 2>&1
	make install > /dev/null
	cd /usr/src/e1000e/src
	make clean > /dev/null 2>&1
	make > /dev/null 2>&1
	make install > /dev/null 2>&1
	cp -r --parents --no-dereference --preserve=all /lib/modules/3.11.4-em ${DEST}/lib/modules/
	echo -e ${OK}

	echo -e "	${STAR} Creating initramfs CPIO archive ... " &&
	rm -f /usr/src/initramfs_data.cpio.gz
	cd ${DEST}
	find . | cpio -o -H newc | gzip -9 > /usr/src/initramfs_data.cpio.gz
	echo -e ${OK}

	echo -e "	${STAR} Rebuilding Linux kernel w/ initramfs from ${DEST} ... " &&
	cp /opt/em/src/config-${VER} /usr/src/linux/.config
	cd /usr/src/linux
	rm -f usr/initramfs_data.cpio*
	echo CONFIG_INITRAMFS_SOURCE=\"/usr/src/initramfs_data.cpio.gz\" >> /usr/src/linux/.config
	echo CONFIG_INITRAMFS_ROOT_UID=0 >> /usr/src/linux/.config
	echo CONFIG_INITRAMFS_ROOT_GID=0 >> /usr/src/linux/.config
	echo CONFIG_INITRAMFS_COMPRESSION_GZIP=y >> /usr/src/linux/.config
	make -j3 bzImage > /dev/null
	cp arch/x86/boot/bzImage /opt/em/images/em-${VER}
	echo -e ${OK}

	echo
	echo -e Your image: ${bldwht}/opt/em/images/em-${VER}${txtrst}
}

resetgps2_description="Resets Garmin GPS to GPRMC-only configuration"
resetgps2_start() {
	echo -ne "	${STAR} Configuring serial ports again (just to make sure) ... "
	setserial -z ${GPS_DEV} low_latency
	setserial -z ${RFID_DEV} low_latency
	if [ "${fishing_area}" == "A" ]; then
		stty -F ${GPS_DEV} 4800
	else
		stty -F ${GPS_DEV} 38400
	fi
	echo -e ${OK}

	echo -ne "	${STAR} Sending sensor configuration ... " &&
	if [ "${fishing_area}" == "A" ]; then
		echo -ne '$PGRMC,A,,,,,,,,A,3,1*65\r\n' > ${GPS_DEV}
		sleep 2
		echo -ne '$PGRMC,A,,,,,,,,A,3,1,,,1*78\r\n' > ${GPS_DEV}
		sleep 2
	else
		echo -ne '$PGRMC,A,,,,,,,,A,8,1,,,1*73\r\n' > ${GPS_DEV}
		sleep 2
		echo -ne '$PGRMC2,5,LOW,,,,,0*04\r\n' > ${GPS_DEV}
		sleep 2
	fi

	echo -ne '$PGRMC1,1,1,2,,,,2,W,N,1,1,1*52\r\n' > ${GPS_DEV}
	sleep 2
	echo -e ${OK}

	echo -ne "	${STAR} Disabling all output sentences ... " &&
	echo -ne '$PGRMO,,2*75\r\n' > ${GPS_DEV}
	sleep 2
	echo -e ${OK}

	echo -ne "	${STAR} Enabling GPRMC ... "
	echo -ne '$PGRMO,GPRMC,1*3D\r\n' > ${GPS_DEV}
	sleep 2
	echo -e ${OK}

	echo -ne "	${STAR} Resetting GPS ... "
	echo -ne '$PGRMI,,,,,,,R\r\n' > ${GPS_DEV}
	echo -e ${OK}
}