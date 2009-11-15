#!/bin/sh

# make-live - utility to build Debian Live systems
#
# Copyright (C) 2006 Daniel Baumann <daniel@debian.org>
# Copyright (C) 2006 Marco Amadori <marco.amadori@gmail.com>
#
# make-live comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
# This is free software, and you are welcome to redistribute it
# under certain conditions; see COPYING for details.

Indices ()
{
	case "${1}" in
		custom)
			# Configure custom sources.list
			case "${LIVE_DISTRIBUTION}" in
				oldstable|"${CODENAME_OLDSTABLE}"|stable|"${CODENAME_STABLE}"|testing|"${CODENAME_TESTING}")
					echo "deb ${LIVE_MIRROR} ${LIVE_DISTRIBUTION} ${LIVE_SECTION}" > "${LIVE_CHROOT}"/etc/apt/sources.list

					if [ "${LIVE_SOURCE}" = "yes" ]
					then
						echo "deb-src ${LIVE_MIRROR} ${LIVE_DISTRIBUTION} ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
					fi

					echo "deb ${LIVE_MIRROR_SECURITY} ${LIVE_DISTRIBUTION}/updates ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list

					if [ "${LIVE_SOURCE}" = "yes" ]
					then
						echo "deb-src ${LIVE_MIRROR_SECURITY} ${LIVE_DISTRIBUTION}/updates ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
					fi
					;;

				unstable|"${CODENAME_UNSTABLE}")
					echo "deb ${LIVE_MIRROR} unstable ${LIVE_SECTION}" > "${LIVE_CHROOT}"/etc/apt/sources.list

					if [ "${LIVE_SOURCE}" = "yes" ]
					then
						echo "deb-src ${LIVE_MIRROR} unstable ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
					fi

					if [ "${LIVE_DISTRIBUTION_EXPERIMENTAL}" = "yes" ]
					then
						echo "deb ${LIVE_MIRROR} experimental ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list

						if [ "${LIVE_SOURCE}" = "yes" ]
						then
							echo "deb-src ${LIVE_MIRROR} experimental ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
						fi

cat > "${LIVE_CHROOT}"/etc/apt/preferences << EOF
Package: *
Pin: release a=experimental
Pin-Priority: 999
EOF
					fi
					;;
			esac
			;;

		default)
			# Configure default sources.list
			case "${LIVE_DISTRIBUTION}" in
				oldstable|"${CODENAME_OLDSTABLE}"|stable|"${CODENAME_STABLE}"|testing|"${CODENAME_TESTING}")
					echo "deb http://ftp.debian.org/debian/ ${LIVE_DISTRIBUTION} ${LIVE_SECTION}" > "${LIVE_CHROOT}"/etc/apt/sources.list

					if [ "${LIVE_SOURCE}" = "yes" ]
					then
						echo "deb-src http://ftp.debian.org/debian/ ${LIVE_DISTRIBUTION} ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
					fi

					echo "deb http://security.debian.org/ ${LIVE_DISTRIBUTION}/updates ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list

					if [ "${LIVE_SOURCE}" = "yes" ]
					then
						echo "deb-src http://security.debian.org/ ${LIVE_DISTRIBUTION}/updates ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
					fi
					;;

				unstable|"${CODENAME_UNSTABLE}")
					echo "deb http://ftp.debian.org/debian/ unstable ${LIVE_SECTION}" > "${LIVE_CHROOT}"/etc/apt/sources.list

					if [ "${LIVE_SOURCE}" = "yes" ]
					then
						echo "deb-src http://ftp.debian.org/debian/ unstable ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
					fi

					if [ "${LIVE_DISTRIBUTION_EXPERIMENTAL}" = "yes" ]
					then
						echo "deb http://ftp.debian.org/debian/ experimental ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list

						if [ "${LIVE_SOURCE}" = "yes" ]
						then
							echo "deb-src http://ftp.debian.org/debian/ experimental ${LIVE_SECTION}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
						fi
					fi
					;;
			esac
			;;
	esac

	# Add custom repositories
	echo "" >> "${LIVE_CHROOT}"/etc/apt/sources.list
	echo "# Custom repositories" >> "${LIVE_CHROOT}"/etc/apt/sources.list

	for NAME in ${LIVE_REPOSITORIES}
	do
		eval REPOSITORY="$`echo LIVE_REPOSITORY_$NAME`"
		eval REPOSITORY_DISTRIBUTION="$`echo LIVE_REPOSITORY_DISTRIBUTION_$NAME`"
		eval REPOSITORY_SECTIONS="$`echo LIVE_REPOSITORY_SECTIONS_$NAME`"

		# Configure /etc/apt/sources.list
		if [ -n "${REPOSITORY_DISTRIBUTION}" ]
		then
			echo "deb ${REPOSITORY} ${REPOSITORY_DISTRIBUTION} ${REPOSITORY_SECTIONS}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
		else
			echo "deb ${REPOSITORY} ${LIVE_DISTRIBUTION} ${REPOSITORY_SECTIONS}" >> "${LIVE_CHROOT}"/etc/apt/sources.list
		fi
	done

	# Update indices
	if [ "${2}" = "initial" ]
	then
		Chroot_exec "apt-get update"
	else
		Chroot_exec "aptitude update"
	fi

	if [ "${LIVE_DISTRIBUTION_EXPERIMENTAL}" = "yes" ]
	then
		# experimental is sometimes broken,
		# therefore this is intentionally kept interactive.
		Chroot_exec "aptitude upgrade" || return 0
		Chroot_exec "aptitude dist-upgrade" || return 0
	fi
}

Genrootfs ()
{
	case "${LIVE_FILESYSTEM}" in
		ext2)
			DU_DIM="`du -ks ${LIVE_CHROOT} | cut -f1`"
			REAL_DIM="`expr ${DU_DIM} + ${DU_DIM} / 20`" # Just 5% more to be sure, need something more sophistcated here...

			genext2fs --size-in-blocks=${REAL_DIM} --reserved-blocks=0 --root="${LIVE_CHROOT}" "${LIVE_ROOT}"/binary/casper/filesystem.ext2
			;;

		plain)
			cd "${LIVE_CHROOT}"
			find . | cpio -pumd "${LIVE_ROOT}"/binary/casper/filesystem.dir
			cd "${OLDPWD}"
			;;

		squashfs)
			if [ -f "${LIVE_ROOT}"/binary/casper/filesystem.squashfs ]
			then
				rm "${LIVE_ROOT}"/binary/casper/filesystem.squashfs
			fi

			mksquashfs "${LIVE_CHROOT}" "${LIVE_ROOT}"/binary/casper/filesystem.squashfs
			;;
	esac
}

Syslinux ()
{
	if [ "${LIVE_ARCHITECTURE}" = "amd64" ] || [ "${LIVE_ARCHITECTURE}" = "i386" ]
	then
		# Install syslinux
		Patch_network apply
		Chroot_exec "aptitude install --assume-yes syslinux"

		case "${1}" in
			iso)
				# Copy syslinux
				mkdir -p "${LIVE_ROOT}"/binary/isolinux
				cp "${LIVE_CHROOT}"/usr/lib/syslinux/isolinux.bin "${LIVE_ROOT}"/binary/isolinux

				# Install syslinux templates
				cp -r "${LIVE_TEMPLATES}"/syslinux/* \
					"${LIVE_ROOT}"/binary/isolinux
				rm -f "${LIVE_ROOT}"/binary/isolinux/pxelinux.cfg

				# Configure syslinux templates
				sed -i -e "s#LIVE_BOOTAPPEND#${LIVE_BOOTAPPEND}#" "${LIVE_ROOT}"/binary/isolinux/isolinux.cfg
				sed -i -e "s/LIVE_DATE/`date +%Y%m%d`/" "${LIVE_ROOT}"/binary/isolinux/f1.txt
				sed -i -e "s/LIVE_VERSION/${VERSION}/" "${LIVE_ROOT}"/binary/isolinux/f10.txt
				;;

			net)
				# Copy syslinux
				mkdir -p "${LIVE_ROOT}"/tftpboot
				cp "${LIVE_ROOT}"/chroot/usr/lib/syslinux/pxelinux.0 "${LIVE_ROOT}"/tftpboot

				# Install syslinux templates
				mkdir -p "${LIVE_ROOT}"/tftpboot/pxelinux.cfg
				cp -r "${LIVE_TEMPLATES}"/syslinux/* \
					"${LIVE_ROOT}"/tftpboot/pxelinux.cfg
				mv "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/pxelinux.cfg "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/default
				rm -f "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/isolinux.cfg
				sed -i -e 's#splash.rle#pxelinux.cfg/splash.rle#' "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/isolinux.txt

				# Configure syslinux templates
				sed -i -e "s/LIVE_SERVER_ADDRESS/${LIVE_SERVER_ADDRESS}/" -e "s#LIVE_SERVER_PATH#${LIVE_SERVER_PATH}#" -e "s#LIVE_BOOTAPPEND#${LIVE_BOOTAPPEND}#" "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/default
				sed -i -e "s/LIVE_DATE/`date +%Y%m%d`/" "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/f1.txt
				sed -i -e "s/LIVE_VERSION/${VERSION}/" "${LIVE_ROOT}"/tftpboot/pxelinux.cfg/f10.txt
				;;
		esac

		# Remove syslinux
		Chroot_exec "aptitude purge --assume-yes syslinux"
		Patch_network deapply
	fi
}

Linuximage ()
{
	# Removing initrd backup files
	rm -f "${LIVE_CHROOT}"/boot/initrd*bak*

	case "${1}" in
		iso)
			# Copy linux-image
			if [ "${LIVE_FLAVOUR}" = "minimal" ]
			then
				mv "${LIVE_CHROOT}"/boot/vmlinuz-* "${LIVE_ROOT}"/binary/isolinux/vmlinuz
				mv "${LIVE_CHROOT}"/boot/initrd.img-* "${LIVE_ROOT}"/binary/isolinux/initrd.gz
				rm -f "${LIVE_CHROOT}"/vmlinuz "${LIVE_CHROOT}"/initrd.img
			else
				cp "${LIVE_CHROOT}"/boot/vmlinuz-* "${LIVE_ROOT}"/binary/isolinux/vmlinuz
				cp "${LIVE_CHROOT}"/boot/initrd.img-* "${LIVE_ROOT}"/binary/isolinux/initrd.gz
			fi
			;;

		net)
			# Copy linux-image
			if [ "${LIVE_FLAVOUR}" = "minimal" ]
			then
				mv "${LIVE_ROOT}"/chroot/boot/vmlinuz-* "${LIVE_ROOT}"/tftpboot/vmlinuz
				mv "${LIVE_ROOT}"/chroot/boot/initrd.img-* "${LIVE_ROOT}"/tftpboot/initrd.gz
			else
				cp "${LIVE_ROOT}"/chroot/boot/vmlinuz-* "${LIVE_ROOT}"/tftpboot/vmlinuz
				cp "${LIVE_ROOT}"/chroot/boot/initrd.img-* "${LIVE_ROOT}"/tftpboot/initrd.gz
			fi
			;;
	esac
}

Memtest ()
{
	if [ "${LIVE_ARCHITECTURE}" = "amd64" ] || [ "${LIVE_ARCHITECTURE}" = "i386" ]
	then
		# Install memtest
		Patch_network apply
		Chroot_exec "aptitude install --assume-yes memtest86+"

		case "$1" in
			iso)
				# Copy memtest
				cp "${LIVE_ROOT}"/chroot/boot/memtest86+.bin "${LIVE_ROOT}"/binary/isolinux/memtest
				;;

			net)
				# Copy memtest
				cp "${LIVE_ROOT}"/chroot/boot/memtest86+.bin "${LIVE_ROOT}"/tftpboot/memtest
				;;
		esac

		# Remove memtest
		Chroot_exec "aptitude purge --assume-yes memtest86+"
		Patch_network deapply
	fi
}

Md5sum ()
{
	# Calculating md5sums
	cd "${LIVE_ROOT}"/binary
	find . -type f -print0 | xargs -0 md5sum > "${LIVE_ROOT}"/md5sum.txt
	cd "${OLDPWD}"

	if [ -d "${LIVE_INCLUDE_IMAGE}" ]
	then
		cd "${LIVE_INCLUDE_IMAGE}"
		find . -type f -print0 | xargs -0 md5sum >> "${LIVE_ROOT}"/md5sum.txt
		cd "${OLDPWD}"
	fi

	mv "${LIVE_ROOT}"/md5sum.txt "${LIVE_ROOT}"/binary
}

Mkisofs ()
{
	case "${1}" in
		binary)
			if [ "${LIVE_ARCHITECTURE}" = "amd64" ] || [ "${LIVE_ARCHITECTURE}" = "i386" ]
			then
				# Create image
				mkisofs -A "Debian Live" -p "Debian Live; http://debian-live.alioth.debian.org/; debian-live-devel@lists.alioth.debian.org" -publisher "Debian Live; http://debian-live.alioth.debian.org/; debian-live-devel@lists.alioth.debian.org" -o "${LIVE_ROOT}"/"${LIVE_IMAGE}"binary.iso -r -J -l -V "Debian Live `date +%Y%m%d`" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table "${LIVE_ROOT}"/binary ${LIVE_INCLUDE_IMAGE}
			else
				echo "W: Bootloader on your architecture not yet supported (Continuing in 5 seconds)."
				sleep 5

				# Create image
				mkisofs -A "Debian Live" -p "Debian Live; http://debian-live.alioth.debian.org/; debian-live-devel@lists.alioth.debian.org" -publisher "Debian Live; http://debian-live.alioth.debian.org/; debian-live-devel@lists.alioth.debian.org" -o "${LIVE_ROOT}"/"${LIVE_IMAGE}"binary.iso -r -J -l -V "Debian Live `date +%Y%m%d`" "${LIVE_ROOT}"/binary ${LIVE_INCLUDE_IMAGE}
			fi
			;;

		source)
			# Create image
			mkisofs -A "Debian Live" -p "Debian Live; http://debian-live.alioth.debian.org/; debian-live-devel@lists.alioth.debian.org" -publisher "Debian Live; http://debian-live.alioth.debian.org/; debian-live-devel@lists.alioth.debian.org" -o "${LIVE_ROOT}"/"${LIVE_IMAGE}"source.iso -r -J -l -V "Debian Live `date +%Y%m%d`" "${LIVE_ROOT}"/source
			;;
	esac
}

Sources ()
{
	# Download sources
	Chroot_exec "dpkg --get-selections" | awk '{ print $1 }' > "${LIVE_CHROOT}"/root/dpkg-selection.txt
	Chroot_exec "xargs --arg-file=/root/dpkg-selection.txt apt-get source --download-only"
	rm -f "${LIVE_CHROOT}"/root/dpkg-selection.txt

	# Sort sources
	for DSC in "${LIVE_CHROOT}"/*.dsc
	do
		SOURCE="`awk '/Source:/ { print $2; }' ${DSC}`"

		if [ "`echo ${SOURCE} | cut -b 1-3`" == "lib" ]
		then
			LETTER="`echo ${SOURCE} | cut -b 1-4`"
		else
			LETTER="`echo ${SOURCE} | cut -b 1`"
		fi

		# Install directory
		install -d -m 0755 "${LIVE_ROOT}"/source/"${LETTER}"/"${SOURCE}"

		# Move sources
		mv "${LIVE_CHROOT}"/"${SOURCE}"_* "${LIVE_ROOT}"/source/"${LETTER}"/"${SOURCE}"
	done
}
