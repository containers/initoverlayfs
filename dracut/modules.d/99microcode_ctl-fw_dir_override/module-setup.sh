#!/usr/bin/bash

# Hack in additional firmware directories for supported caveats.
#
# SPDX-License-Identifier: CC0-1.0

check() {
	return 0
}

install() {
	local FW_DIR=/lib/firmware
	local DATA_DIR=/usr/share/microcode_ctl/ucode_with_caveats
	local CFG_DIR="/etc/microcode_ctl/ucode_with_caveats"
	local check_caveats=/usr/libexec/microcode_ctl/check_caveats

	local verbose_opt
	local cc_out
	local path
	local ignored
	local do_skip_host_only
	local p

	verbose_opt=
	[ 4 -gt "$stdloglvl" ] || verbose_opt="-v"

	# HACK: we override external fw_dir variable in order to get
	#       an additional ucode based on the kernel version.
	dinfo "  microcode_ctl module: mangling fw_dir"

	[ -z "$fw_dir_l" ] || {
		dinfo "    microcode_ctl: avoid touching fw_dir as" \
		      "it has been changed (fw_dir_l is '$fw_dir_l')"

		return 0
	}

	# Reset fw_dir to avoid inclusion of kernel-version-specific directories
	# populated with microcode for the late load
	[ "x$fw_dir" != \
	  "x/lib/firmware/updates /lib/firmware /lib/firmware/$kernel" ] || {
		fw_dir="/lib/firmware/updates /lib/firmware"
		dinfo "    microcode_ctl: reset fw_dir to \"${fw_dir}\""
	}

	fw_dir_add=""
	while read -d $'\n' -r i; do
		dinfo "    microcode_ctl: processing data directory " \
		      "\"$DATA_DIR/$i\"..."

		if [ "x" != "x$hostonly" ]; then
			do_skip_host_only=0

			local sho_overrides="
				$CFG_DIR/skip-host-only-check
				$CFG_DIR/skip-host-only-check-$i
				$FW_DIR/$kernel/skip-host-only-check
				$FW_DIR/$kernel/skip-host-only-check-$i"

			for p in $(echo "$sho_overrides"); do
				[ -e "$p" ] || continue

				do_skip_host_only=1
				dinfo "    microcode_ctl: $i; skipping" \
				      "Host-Only check, since \"$p\" exists."
				break
			done
		else
			do_skip_host_only=1
		fi

		match_model_opt=""
		[ 1 = "$do_skip_host_only" ] || match_model_opt="-m"

		if ! cc_out=$($check_caveats -e -k "$kernel" -c "$i" \
				$verbose_opt $match_model_opt)
		then
			dinfo "    microcode_ctl: kernel version \"$kernel\"" \
			      "failed early load check for \"$i\", skipping"
			continue
		fi

		path=$(printf "%s" "$cc_out" | sed -n 's/^paths //p')
		[ -n "$path" ] || {
			ignored=$(printf "%s" "$cc_out" | \
					sed -n 's/^skip_cfgs //p')

			if [ -n "$ignored" ]; then
				dinfo "    microcode_ctl: configuration" \
				      "\"$i\" is ignored"
			else
				dinfo "    microcode_ctl: no microcode paths" \
				      "are associated with \"$i\", skipping"
			fi

			continue
		}

		dinfo "      microcode_ctl: $i: caveats check for kernel" \
		      "version \"$kernel\" passed, adding" \
		      "\"$DATA_DIR/$i\" to fw_dir variable"

		if [ 0 -eq "$do_skip_host_only" ]; then
			fw_dir_add="$DATA_DIR/$i "
		else
			fw_dir_add="$DATA_DIR/$i $fw_dir_add"
		fi
	# The list of directories is reverse-sorted in order to preserve the
	# "last wins" policy in case of presence of multiple microcode
	# revisions.
	#
	# In case of hostonly == 0, all microcode revisions will be included,
	# but since the microcode search is done with the "first wins" policy
	# by the (early) microcode loading code, the correct microcode revision
	# still has to be picked.
	#
	# Note that dracut without patch [1] puts only the last directory
	# in the early cpio; we try to address this by putting only the last
	# matching caveat in the search path, but that workaround works only
	# for host-only mode; non-host-only mode early cpio generation is still
	# broken without that patch.
	#
	# [1] https://github.com/dracutdevs/dracut/commit/c44d2252bb4b
	done <<-EOF
	$(find "$DATA_DIR" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" \
		| LC_ALL=C sort)
	EOF

	fw_dir="${fw_dir_add}${fw_dir}"
	dinfo "    microcode_ctl: final fw_dir: \"${fw_dir}\""
}

