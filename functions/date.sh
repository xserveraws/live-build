#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016 Chris Lamb <lamby@debian.org>
##
## live-build comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Date ()
{
	FORMAT="${1}"

	if [ "${SOURCE_DATE_EPOCH}" = "" ]
	then
		date "${FORMAT}"
	else
		LC_ALL=C date --utc --date="@${SOURCE_DATE_EPOCH}" "${FORMAT}"
	fi
}
