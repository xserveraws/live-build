#!/bin/sh -x

set -e

BUILD="weekly"

AUTOBUILD_ARCHITECTURES="`dpkg --print-architecture`"
AUTOBUILD_DISTRIBUTIONS="lenny"
AUTOBUILD_PACKAGES_LISTS="standard gnome-desktop kde-desktop xfce-desktop"
AUTOBUILD_OPTIONS="--apt-recommends disabled"

AUTOBUILD_DATE="`date +%Y%m%d`"
AUTOBUILD_DESTDIR="/srv/debian-unofficial/ftp/debian-live"
AUTOBUILD_TEMPDIR="/srv/tmp"

AUTOBUILD_MIRROR="http://ftp.de.debian.org/debian/"
AUTOBUILD_MIRROR_SECURITY="http://ftp.de.debian.org/debian-security/"

# Check for live-helper availability
if [ ! -x /usr/bin/make-live ]
then
	exit 0
fi

# Check for live-helper defaults
#if [ -r /etc/default/live-helper ]
#then
#	. /etc/default/live-helper
#else
#	echo "E: /etc/default/live-helper missing."
#	exit 1
#fi

# Check for autobuild
#if [ "${AUTOBUILD}" != "enabled" ]
#then
#	exit 0
#fi

# Check for build directory
if [ ! -d "${AUTOBUILD_TEMPDIR}" ]
then
	mkdir -p "${AUTOBUILD_TEMPDIR}"/debian-live
else
	# FIXME: maybe we should just remove the left overs.
	echo "E: ${AUTOBUILD_TEMPDIR} needs cleanup."
	exit 1
fi

for ARCHITECTURE in ${AUTOBUILD_ARCHITECTURES}
do
	for DISTRIBUTION in ${AUTOBUILD_DISTRIBUTIONS}
	do
		for PACKAGES_LIST in ${AUTOBUILD_PACKAGES_LISTS}
		do
			if [ ! -f "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-iso-log.txt ]
		then
			# Generating images
			mkdir -p "${AUTOBUILD_TEMPDIR}"/debian-live
			cd "${AUTOBUILD_TEMPDIR}"
			echo "Begin: `date -R`" > "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt
			make-live -b iso -s generic --distribution ${DISTRIBUTION} --packages-lists ${PACKAGES_LIST} --mirror-build ${AUTOBUILD_MIRROR} --mirror-build-security ${AUTOBUILD_MIRROR_SECURITY} --source enabled ${AUTOBUILD_OPTIONS} >> "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt 2>&1
			echo "End: `date -R`" >> "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt
		fi

		if [ -f "${AUTOBUILD_TEMPDIR}"/debian-live/binary.iso ] && [ -f "${AUTOBUILD_TEMPDIR}"/debian-live/source.tar ]
		then
			# Moving logs
			mkdir -p "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-iso-log.txt
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/packages.txt "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-iso-packages.txt

			# Moving images
			mkdir -p "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/${ARCHITECTURE}
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/binary.iso "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/${ARCHITECTURE}/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}.iso

			mkdir -p "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/source
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/source.tar "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/source/debian-live-${DISTRIBUTION}-source-${PACKAGES_LIST}.tar
		fi

		if [ ! -f "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-usb-hdd-log.txt ]
		then
			# Workaround of missing multi-binary support in live-helper
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/binary/casper "${AUTOBUILD_TEMPDIR}"/debian-live/casper.tmp
			rm -rf "${AUTOBUILD_TEMPDIR}"/debian-live/binary* "${AUTOBUILD_TEMPDIR}"/debian-live/.stage/binary_*
			mkdir "${AUTOBUILD_TEMPDIR}"/debian-live/binary
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/casper.tmp "${AUTOBUILD_TEMPDIR}"/debian-live/binary/casper
			touch "${AUTOBUILD_TEMPDIR}"/debian-live/.stage/binary_chroot
			touch "${AUTOBUILD_TEMPDIR}"/debian-live/.stage/binary_rootfs

			# Generating images
			mkdir -p "${AUTOBUILD_TEMPDIR}"/debian-live
			cd "${AUTOBUILD_TEMPDIR}"
			echo "Begin: `date -R`" > "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt
			make-live -b usb-hdd -s generic --distribution ${DISTRIBUTION} --packages-lists ${PACKAGES_LIST} --mirror-build ${AUTOBUILD_MIRROR} --mirror-build-security ${AUTOBUILD_MIRROR_SECURITY} --source disabled ${AUTOBUILD_OPTIONS} >> "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt 2>&1
			echo "End: `date -R`" >> "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt
		fi

		if [ -f "${AUTOBUILD_TEMPDIR}"/debian-live/binary.img ]
		then
			# Moving logs
			mkdir -p "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/log.txt "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-usb-hdd-log.txt
			cp "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-iso-packages.txt "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/log/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}_${AUTOBUILD_DATE}-usb-hdd-packages.txt

			# Moving images
			mkdir -p "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/${ARCHITECTURE}
			mv "${AUTOBUILD_TEMPDIR}"/debian-live/binary.img "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/${ARCHITECTURE}/debian-live-${DISTRIBUTION}-${ARCHITECTURE}-${PACKAGES_LIST}.img
		fi

		# Cleanup
		cd "${AUTOBUILD_TEMPDIR}"/debian-live
		lh_clean
		done
	done
done

# Cleanup
if [ -e "${AUTOBUILD_TEMPDIR}"/debian-live/chroot/proc/version ]
then
	umount "${AUTOBUILD_TEMPDIR}"/debian-live/chroot/proc
fi

if [ -d "${AUTOBUILD_TEMPDIR}"/debian-live/chroot/sys/kernel ]
then
	umount "${AUTOBUILD_TEMPDIR}"/debian-live/chroot/sys
fi

rm -rf "${AUTOBUILD_TEMPDIR}"

# md5sums
for DIRECTORY in "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/${AUTOBUILD_DATE}/*
do
	cd "${DIRECTORY}"
	md5sum * > MD5SUMS
done

# Current symlink
rm -f "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/current
ln -s ${AUTOBUILD_DATE} "${AUTOBUILD_DESTDIR}"/"${BUILD}"-builds/current
