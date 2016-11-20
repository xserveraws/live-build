#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016 Chris Lamb <lamby@debian.org>
##
## live-build comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


# "Clamp" the time to SOURCE_DATE_EPOCH when the file is more recent to keep
# the original times for files that have not been created or modified during
# the build process:
Clamp_mtimes ()
{
	find "${@}" -xdev -newermt "@${SOURCE_DATE_EPOCH}" -print0 | \
		xargs -0r touch --no-dereference --date="@${SOURCE_DATE_EPOCH}"
}
