#!/usr/bin/bash

_DRACUT_KDUMP_NM_TMP_DIR="$DRACUT_TMPDIR/$$-DRACUT_KDUMP_NM"

_save_kdump_netifs() {
    unique_netifs[$1]=1
}

_get_kdump_netifs() {
    echo -n "${!unique_netifs[@]}"
}

kdump_module_init() {
    if ! [[ -d "${initdir}/tmp" ]]; then
        mkdir -p "${initdir}/tmp"
    fi

    mkdir -p "$_DRACUT_KDUMP_NM_TMP_DIR"

    . /lib/kdump/kdump-lib.sh
}

check() {
    [[ $debug ]] && set -x
    #kdumpctl sets this explicitly
    if [[ -z $IN_KDUMP ]] || [[ ! -f /etc/kdump.conf ]]; then
        return 1
    fi
    return 0
}

depends() {
    local _dep="base shutdown"

    kdump_module_init

    add_opt_module() {
        [[ " $omit_dracutmodules " != *\ $1\ * ]] && _dep="$_dep $1"
    }

    if is_squash_available; then
        add_opt_module squash
    else
        dwarning "Required modules to build a squashed kdump image is missing!"
    fi

    if is_wdt_active; then
        add_opt_module watchdog
    fi

    if is_ssh_dump_target; then
        _dep="$_dep ssh-client"
    fi

    if is_lvm2_thinp_dump_target; then
        if dracut --list-modules | grep -q lvmthinpool-monitor; then
            add_opt_module lvmthinpool-monitor
        else
            dwarning "Required lvmthinpool-monitor modules is missing! Please upgrade dracut >= 057."
        fi
    fi

    if [[ "$(uname -m)" == "s390x" ]]; then
        _dep="$_dep znet"
    fi

    if [[ -n "$(ls -A /sys/class/drm 2> /dev/null)" ]] || [[ -d /sys/module/hyperv_fb ]]; then
        add_opt_module drm
    fi

    if is_generic_fence_kdump || is_pcs_fence_kdump; then
        _dep="$_dep network"
    fi

    echo "$_dep"
}

kdump_is_bridge() {
    [[ -d /sys/class/net/"$1"/bridge ]]
}

kdump_is_bond() {
    [[ -d /sys/class/net/"$1"/bonding ]]
}

kdump_is_team() {
    [[ -f /usr/bin/teamnl ]] && teamnl "$1" ports &> /dev/null
}

kdump_is_vlan() {
    [[ -f /proc/net/vlan/"$1" ]]
}

# $1: netdev name
source_ifcfg_file() {
    local ifcfg_file

    dwarning "Network Scripts are deprecated. You are encouraged to set up network by NetworkManager."
    ifcfg_file=$(get_ifcfg_filename "$1")
    if [[ -f ${ifcfg_file} ]]; then
        . "${ifcfg_file}"
    else
        dwarning "The ifcfg file of $1 is not found!"
    fi
}

# $1: repeat times
# $2: string to be repeated
# $3: separator
repeatedly_join_str() {
    local _count="$1"
    local _str="$2"
    local _separator="$3"
    local i _res

    if [[ $_count -le 0 ]]; then
        echo -n ""
        return
    fi

    i=0
    _res="$_str"
    ((_count--))

    while [[ $i -lt $_count ]]; do
        ((i++))
        _res="${_res}${_separator}${_str}"
    done
    echo -n "$_res"
}

# $1: prefix
# $2: ipv6_flag="-6" indicates it's IPv6
# Given a prefix, calculate the netmask (equivalent of "ipcalc -m")
# by concatenating three parts,
#  1) the groups with all bits set 1
#  2) a group with partial bits set to 0
#  3) the groups with all bits set to 0
cal_netmask_by_prefix() {
    local _prefix="$1"
    local _ipv6_flag="$2" _ipv6
    local _bits_per_octet=8
    local _count _res _octets_per_group _octets_total _seperator _total_groups
    local _max_group_value _max_group_value_repr _bits_per_group _tmp _zero_bits

    if [[ $_ipv6_flag == "-6" ]]; then
        _ipv6=1
    else
        _ipv6=0
    fi

    if [[ $_prefix -lt 0 || $_prefix -gt 128 ]] \
        || ( ((!_ipv6)) && [[ $_prefix -gt 32 ]]); then
        derror "Bad prefix:$_prefix for calculating netmask"
        exit 1
    fi

    if ((_ipv6)); then
        _octets_per_group=2
        _octets_total=16
        _seperator=":"
    else
        _octets_per_group=1
        _octets_total=4
        _seperator="."
    fi

    _total_groups=$((_octets_total / _octets_per_group))
    _bits_per_group=$((_octets_per_group * _bits_per_octet))
    _max_group_value=$(((1 << _bits_per_group) - 1))

    if ((_ipv6)); then
        _max_group_value_repr=$(printf "%x" $_max_group_value)
    else
        _max_group_value_repr="$_max_group_value"
    fi

    _count=$((_prefix / _octets_per_group / _bits_per_octet))
    _first_part=$(repeatedly_join_str "$_count" "$_max_group_value_repr" "$_seperator")
    _res="$_first_part"

    _tmp=$((_octets_total * _bits_per_octet - _prefix))
    _zero_bits=$((_tmp % _bits_per_group))
    if [[ $_zero_bits -ne 0 ]]; then
        _second_part=$((_max_group_value >> _zero_bits << _zero_bits))
        if ((_ipv6)); then
            _second_part=$(printf "%x" $_second_part)
        fi
        ((_count++))
        if [[ -z $_first_part ]]; then
            _res="$_second_part"
        else
            _res="${_first_part}${_seperator}${_second_part}"
        fi
    fi

    _count=$((_total_groups - _count))
    if [[ $_count -eq 0 ]]; then
        echo -n "$_res"
        return
    fi

    if ((_ipv6)) && [[ $_count -gt 1 ]]; then
        # use condensed notion for IPv6
        _third_part=":"
    else
        _third_part=$(repeatedly_join_str "$_count" "0" "$_seperator")
    fi

    if [[ -z $_res ]] && ((!_ipv6)); then
        echo -n "${_third_part}"
    else
        echo -n "${_res}${_seperator}${_third_part}"
    fi
}

kdump_get_mac_addr() {
    cat "/sys/class/net/$1/address"
}

#Bonding or team master modifies the mac address
#of its slaves, we should use perm address
kdump_get_perm_addr() {
    local addr
    addr=$(ethtool -P "$1" | sed -e 's/Permanent address: //')
    if [[ -z $addr ]] || [[ $addr == "00:00:00:00:00:00" ]]; then
        derror "Can't get the permanent address of $1"
    else
        echo "$addr"
    fi
}

apply_nm_initrd_generator_timeouts() {
    local _timeout_conf

    _timeout_conf=$_DRACUT_KDUMP_NM_TMP_DIR/timeout_conf
    cat << EOF > "$_timeout_conf"
[device-95-kdump]
carrier-wait-timeout=30000

[connection-95-kdump]
ipv4.dhcp-timeout=90
ipv6.dhcp-timeout=90
EOF

    inst "$_timeout_conf" "/etc/NetworkManager/conf.d/95-kdump-timeouts.conf"
}

use_ipv4_or_ipv6() {
    local _netif=$1 _uuid=$2

    if [[ -v "ipv4_usage[$_netif]" ]]; then
        nmcli connection modify --temporary "$_uuid" ipv4.may-fail no &> >(ddebug)
    fi

    if [[ -v "ipv6_usage[$_netif]" ]]; then
        nmcli connection modify --temporary "$_uuid" ipv6.may-fail no &> >(ddebug)
    fi

    if [[ -v "ipv4_usage[$_netif]" ]] && [[ ! -v "ipv6_usage[$_netif]" ]]; then
        nmcli connection modify --temporary "$_uuid" ipv6.method disabled &> >(ddebug)
    elif [[ ! -v "ipv4_usage[$_netif]" ]] && [[ -v "ipv6_usage[$_netif]" ]]; then
        nmcli connection modify --temporary "$_uuid" ipv4.method disabled &> >(ddebug)
    fi
}

_clone_nmconnection() {
    local _clone_output _name _unique_id

    _unique_id=$1
    _name=$(nmcli --get-values connection.id connection show "$_unique_id")
    if _clone_output=$(nmcli connection clone --temporary uuid "$_unique_id" "$_name"); then
        sed -E -n "s/.* \(.*\) cloned as.*\((.*)\)\.$/\1/p" <<< "$_clone_output"
        return 0
    fi

    return 1
}

_match_nmconnection_by_mac() {
    local _unique_id _dev _mac _mac_field

    _unique_id=$1
    _dev=$2

    _mac=$(kdump_get_perm_addr "$_dev")
    [[ $_mac != 'not set' ]] || return
    _mac_field=$(nmcli --get-values connection.type connection show "$_unique_id").mac-address
    nmcli connection modify --temporary "$_unique_id" "$_mac_field" "$_mac" &> >(ddebug)
    nmcli connection modify --temporary "$_unique_id" "connection.interface-name" "" &> >(ddebug)
}

# Clone and modify NM connection profiles
#
# This function makes use of "nmcli clone" to automatically convert ifcfg-*
# files to Networkmanager .nmconnection connection profiles and also modify the
# properties of .nmconnection if necessary.
clone_and_modify_nmconnection() {
    local _dev _cloned_nmconnection_file_path _tmp_nmconnection_file_path _old_uuid _uuid

    _dev=$1
    _nmconnection_file_path=$2

    _old_uuid=$(nmcli --get-values connection.uuid connection show filename "$_nmconnection_file_path")

    if ! _uuid=$(_clone_nmconnection "$_old_uuid"); then
        derror "Failed to clone $_old_uuid"
        exit 1
    fi

    use_ipv4_or_ipv6 "$_dev" "$_uuid"

    nmcli connection modify --temporary uuid "$_uuid" connection.wait-device-timeout 60000 &> >(ddebug)
    # For physical NIC i.e. non-user created NIC, ask NM to match a
    # connection profile based on MAC address
    _match_nmconnection_by_mac "$_uuid" "$_dev"

    _cloned_nmconnection_file_path=$(nmcli --get-values UUID,FILENAME connection show | sed -n "s/^${_uuid}://p")
    _tmp_nmconnection_file_path=$_DRACUT_KDUMP_NM_TMP_DIR/$(basename "$_nmconnection_file_path")
    cp "$_cloned_nmconnection_file_path" "$_tmp_nmconnection_file_path"
    # change uuid back to old value in case it's refered by other connection
    # profile e.g. connection.master could be interface name of the master
    # device or UUID of the master connection.
    sed -i -E "s/(^uuid=).*$/\1${_old_uuid}/g" "$_tmp_nmconnection_file_path"
    nmcli connection del "$_uuid" &> >(ddebug)
    echo -n "$_tmp_nmconnection_file_path"
}

_install_nmconnection() {
    local _src _nmconnection_name _dst

    _src=$1
    _nmconnection_name=$(basename "$_src")
    _dst="/etc/NetworkManager/system-connections/$_nmconnection_name"
    inst "$_src" "$_dst"
}

kdump_install_nmconnections() {
    local _netif _nm_conn_path _cloned_nm_path

    while IFS=: read -r _netif _nm_conn_path; do
        [[ -v "unique_netifs[$_netif]" ]] || continue
        if _cloned_nm_path=$(clone_and_modify_nmconnection "$_netif" "$_nm_conn_path"); then
            _install_nmconnection "$_cloned_nm_path"
        else
            derror "Failed to install the .nmconnection for $_netif"
            exit 1
        fi
    done <<< "$(nmcli -t -f device,filename connection show --active)"

    # Stop dracut 35network-manger to calling nm-initrd-generator.
    # Note this line of code can be removed after NetworkManager >= 1.35.2
    # gets released.
    echo > "${initdir}/usr/libexec/nm-initrd-generator"
}

kdump_install_nm_netif_allowlist() {
    local _netif _except_netif _netif_allowlist _netif_allowlist_nm_conf

    for _netif in $1; do
        _per_mac=$(kdump_get_perm_addr "$_netif")
        if [[ "$_per_mac" != 'not set' ]]; then
            _except_netif="mac:$_per_mac"
        else
            _except_netif="interface-name:$_netif"
        fi
        _netif_allowlist="${_netif_allowlist}except:${_except_netif};"
    done

    _netif_allowlist_nm_conf=$_DRACUT_KDUMP_NM_TMP_DIR/netif_allowlist_nm_conf
    cat << EOF > "$_netif_allowlist_nm_conf"
[device-others]
match-device=${_netif_allowlist}
managed=false
EOF

    inst "$_netif_allowlist_nm_conf" "/etc/NetworkManager/conf.d/10-kdump-netif_allowlist.conf"
}

_get_nic_driver() {
    ethtool -i "$1" | sed -n -E "s/driver: (.*)/\1/p"
}

_get_hpyerv_physical_driver() {
    local _physical_nic

    _physical_nic=$(find /sys/class/net/"$1"/ -name 'lower_*' | sed -En "s/\/.*lower_(.*)/\1/p")
    [[ -n $_physical_nic ]] || return
    _get_nic_driver "$_physical_nic"
}

kdump_install_nic_driver() {
    local _netif _driver _drivers

    _drivers=()

    for _netif in $1; do
        [[ $_netif == lo ]] && continue
        _driver=$(_get_nic_driver "$_netif")
        if [[ -z $_driver ]]; then
            derror "Failed to get the driver of $_netif"
            exit 1
        fi

        if [[ $_driver == "802.1Q VLAN Support" ]]; then
            # ethtool somehow doesn't return the driver name for a VLAN NIC
            _driver=8021q
        elif [[ $_driver == "team" ]]; then
            # install the team mode drivers like team_mode_roundrobin.ko as well
            _driver='=drivers/net/team'
        elif [[ $_driver == "hv_netvsc" ]]; then
            # A Hyper-V VM may have accelerated networking
            # https://learn.microsoft.com/en-us/azure/virtual-network/accelerated-networking-overview
            # Install the driver of physical NIC as well
            _drivers+=("$(_get_hpyerv_physical_driver "$_netif")")
        fi

        _drivers+=("$_driver")
    done

    [[ -n ${_drivers[*]} ]] || return
    instmods "${_drivers[@]}"
}

kdump_setup_bridge() {
    local _netdev=$1
    local _dev
    for _dev in "/sys/class/net/$_netdev/brif/"*; do
        [[ -e $_dev ]] || continue
        _dev=${_dev##*/}
        if kdump_is_bond "$_dev"; then
            kdump_setup_bond "$_dev" || return 1
        elif kdump_is_team "$_dev"; then
            kdump_setup_team "$_dev"
        elif kdump_is_vlan "$_dev"; then
            kdump_setup_vlan "$_dev"
        fi
        _save_kdump_netifs "$_dev"
    done
}

kdump_setup_bond() {
    local _netdev="$1"
    local _dev

    for _dev in $(< "/sys/class/net/$_netdev/bonding/slaves"); do
        _save_kdump_netifs "$_dev"
    done
}

kdump_setup_team() {
    local _netdev=$1
    local _dev
    for _dev in $(teamnl "$_netdev" ports | awk -F':' '{print $2}'); do
        _save_kdump_netifs "$_dev"
    done
}

kdump_setup_vlan() {
    local _netdev=$1
    local _parent_netif

    _parent_netif="$(awk '/^Device:/{print $2}' /proc/net/vlan/"$_netdev")"

    #Just support vlan over bond and team
    if kdump_is_bridge "$_parent_netif"; then
        derror "Vlan over bridge is not supported!"
        exit 1
    elif kdump_is_bond "$_parent_netif"; then
        kdump_setup_bond "$_parent_netif" || return 1
    elif kdump_is_team "$_parent_netif"; then
        kdump_setup_team "$_parent_netif" || return 1
    fi

    _save_kdump_netifs "$_parent_netif"
}

_find_znet_nmconnection() {
    LANG=C grep -s -E -i -l \
        "^s390-subchannels=([0-9]\.[0-9]\.[a-f0-9]+;){0,2}" \
        "$1"/*.nmconnection | LC_ALL=C sed -e "$2"
}

# setup s390 znet
#
# Note part of code is extracted from ccw_init provided by s390utils
kdump_setup_znet() {
    local _config_file _unique_name _NM_conf_dir
    local __sed_discard_ignored_files='/\(~\|\.bak\|\.old\|\.orig\|\.rpmnew\|\.rpmorig\|\.rpmsave\)$/d'

    if [[ "$(uname -m)" != "s390x" ]]; then
        return
    fi

    _NM_conf_dir="/etc/NetworkManager/system-connections"

    _config_file=$(_find_znet_nmconnection "$initdir/$_NM_conf_dir" "$__sed_discard_ignored_files")
    if [[ -n "$_config_file" ]]; then
        ddebug "$_config_file has already contained the znet config"
        return
    fi

    _config_file=$(LANG=C grep -s -E -i -l \
        "^[[:space:]]*SUBCHANNELS=['\"]?([0-9]\.[0-9]\.[a-f0-9]+,){0,2}" \
        /etc/sysconfig/network-scripts/ifcfg-* \
        | LC_ALL=C sed -e "$__sed_discard_ignored_files")

    if [[ -z "$_config_file" ]]; then
        _config_file=$(_find_znet_nmconnection "$_NM_conf_dir" "$__sed_discard_ignored_files")
    fi

    if [[ -n "$_config_file" ]]; then
        _unique_name=$(cat /proc/sys/kernel/random/uuid)
        nmcli connection clone --temporary "$_config_file" "$_unique_name" &> >(ddebug)
        nmcli connection modify --temporary "$_unique_name" connection.autoconnect false
        inst "/run/NetworkManager/system-connections/${_unique_name}.nmconnection" "${_NM_conf_dir}/${_unique_name}.nmconnection"
        nmcli connection del "$_unique_name" &> >(ddebug)
    fi

}

kdump_get_remote_ip() {
    local _remote _remote_temp
    _remote=$(get_remote_host "$1")
    if is_hostname "$_remote"; then
        _remote_temp=$(getent ahosts "$_remote" | grep -v : | head -n 1)
        if [[ -z $_remote_temp ]]; then
            _remote_temp=$(getent ahosts "$_remote" | head -n 1)
        fi
        _remote=$(echo "$_remote_temp" | awk '{print $1}')
    fi
    echo "$_remote"
}

# Collect netifs needed by kdump
# $1: destination host
kdump_collect_netif_usage() {
    local _destaddr _srcaddr _route _netdev

    _destaddr=$(kdump_get_remote_ip "$1")
    _route=$(kdump_get_ip_route "$_destaddr")
    _srcaddr=$(kdump_get_ip_route_field "$_route" "src")
    _netdev=$(kdump_get_ip_route_field "$_route" "dev")

    if kdump_is_bridge "$_netdev"; then
        kdump_setup_bridge "$_netdev"
    elif kdump_is_bond "$_netdev"; then
        kdump_setup_bond "$_netdev" || return 1
    elif kdump_is_team "$_netdev"; then
        kdump_setup_team "$_netdev"
    elif kdump_is_vlan "$_netdev"; then
        kdump_setup_vlan "$_netdev"
    fi
    _save_kdump_netifs "$_netdev"

    if [[ ! -f ${initdir}/etc/cmdline.d/50neednet.conf ]]; then
        # network-manager module needs this parameter
        echo "rd.neednet" >> "${initdir}/etc/cmdline.d/50neednet.conf"
    fi

    if [[ ! -f ${initdir}/etc/cmdline.d/60kdumpip.conf ]]; then
        echo "kdump_remote_ip=$_destaddr" > "${initdir}/etc/cmdline.d/60kdumpip.conf"
    fi

    if is_ipv6_address "$_srcaddr"; then
        ipv6_usage[$_netdev]=1
    else
        ipv4_usage[$_netdev]=1
    fi
}

# Setup dracut to bring up network interface that enable
# initramfs accessing giving destination
kdump_install_net() {
    local _netifs

    _netifs=$(_get_kdump_netifs)
    if [[ -n "$_netifs" ]]; then
        kdump_install_nmconnections
        apply_nm_initrd_generator_timeouts
        kdump_setup_znet
        kdump_install_nm_netif_allowlist "$_netifs"
        kdump_install_nic_driver "$_netifs"
    fi
}

# install etc/kdump/pre.d and /etc/kdump/post.d
kdump_install_pre_post_conf() {
    if [[ -d /etc/kdump/pre.d ]]; then
        for file in /etc/kdump/pre.d/*; do
            if [[ -x $file ]]; then
                dracut_install "$file"
            elif [[ $file != "/etc/kdump/pre.d/*" ]]; then
                echo "$file is not executable"
            fi
        done
    fi

    if [[ -d /etc/kdump/post.d ]]; then
        for file in /etc/kdump/post.d/*; do
            if [[ -x $file ]]; then
                dracut_install "$file"
            elif [[ $file != "/etc/kdump/post.d/*" ]]; then
                echo "$file is not executable"
            fi
        done
    fi
}

default_dump_target_install_conf() {
    local _target _fstype
    local _mntpoint _save_path

    is_user_configured_dump_target && return

    _save_path=$(get_bind_mount_source "$(get_save_path)")
    _target=$(get_target_from_path "$_save_path")
    _mntpoint=$(get_mntpoint_from_target "$_target")

    _fstype=$(get_fs_type_from_target "$_target")
    if is_fs_type_nfs "$_fstype"; then
        kdump_collect_netif_usage "$_target"
        _fstype="nfs"
    else
        _target=$(kdump_get_persistent_dev "$_target")
    fi

    echo "$_fstype $_target" >> "${initdir}/tmp/$$-kdump.conf"

    # don't touch the path under root mount
    if [[ $_mntpoint != "/" ]]; then
        _save_path=${_save_path##"$_mntpoint"}
    fi

    #erase the old path line, then insert the parsed path
    sed -i "/^path/d" "${initdir}/tmp/$$-kdump.conf"
    echo "path $_save_path" >> "${initdir}/tmp/$$-kdump.conf"
}

#install kdump.conf and what user specifies in kdump.conf
kdump_install_conf() {
    local _opt _val _pdev

    kdump_read_conf > "${initdir}/tmp/$$-kdump.conf"

    while read -r _opt _val; do
        # remove inline comments after the end of a directive.
        case "$_opt" in
            raw)
                _pdev=$(persistent_policy="by-id" kdump_get_persistent_dev "$_val")
                sed -i -e "s#^${_opt}[[:space:]]\+$_val#$_opt $_pdev#" "${initdir}/tmp/$$-kdump.conf"
                ;;
            ext[234] | xfs | btrfs | minix | virtiofs)
                _pdev=$(kdump_get_persistent_dev "$_val")
                sed -i -e "s#^${_opt}[[:space:]]\+$_val#$_opt $_pdev#" "${initdir}/tmp/$$-kdump.conf"
                ;;
            ssh | nfs)
                kdump_collect_netif_usage "$_val"
                ;;
            dracut_args)
                if [[ $(get_dracut_args_fstype "$_val") == nfs* ]]; then
                    kdump_collect_netif_usage "$(get_dracut_args_target "$_val")"
                fi
                ;;
            kdump_pre | kdump_post | extra_bins)
                # shellcheck disable=SC2086
                dracut_install $_val
                ;;
            core_collector)
                dracut_install "${_val%%[[:blank:]]*}"
                ;;
        esac
    done <<< "$(kdump_read_conf)"

    kdump_install_pre_post_conf

    default_dump_target_install_conf

    kdump_configure_fence_kdump "${initdir}/tmp/$$-kdump.conf"
    inst "${initdir}/tmp/$$-kdump.conf" "/etc/kdump.conf"
    rm -f "${initdir}/tmp/$$-kdump.conf"
}

# Default sysctl parameters should suffice for kdump kernel.
# Remove custom configurations sysctl.conf & sysctl.d/*
remove_sysctl_conf() {

    # As custom configurations like vm.min_free_kbytes can lead
    # to OOM issues in kdump kernel, avoid them
    rm -f "${initdir}/etc/sysctl.conf"
    rm -rf "${initdir}/etc/sysctl.d"
    rm -rf "${initdir}/run/sysctl.d"
    rm -rf "${initdir}/usr/lib/sysctl.d"
}

kdump_iscsi_get_rec_val() {

    local result

    # The open-iscsi 742 release changed to using flat files in
    # /var/lib/iscsi.

    result=$(/sbin/iscsiadm --show -m session -r "$1" | grep "^${2} = ")
    result=${result##* = }
    echo "$result"
}

kdump_get_iscsi_initiator() {
    local _initiator
    local initiator_conf="/etc/iscsi/initiatorname.iscsi"

    [[ -f $initiator_conf ]] || return 1

    while read -r _initiator; do
        [[ -z ${_initiator%%#*} ]] && continue # Skip comment lines

        case $_initiator in
            InitiatorName=*)
                initiator=${_initiator#InitiatorName=}
                echo "rd.iscsi.initiator=${initiator}"
                return 0
                ;;
            *) ;;
        esac
    done < ${initiator_conf}

    return 1
}

# Figure out iBFT session according to session type
is_ibft() {
    [[ "$(kdump_iscsi_get_rec_val "$1" "node.discovery_type")" == fw ]]
}

kdump_setup_iscsi_device() {
    local path=$1
    local tgt_name
    local tgt_ipaddr
    local username
    local password
    local userpwd_str
    local username_in
    local password_in
    local userpwd_in_str
    local netroot_str
    local initiator_str
    local netroot_conf="${initdir}/etc/cmdline.d/50iscsi.conf"
    local initiator_conf="/etc/iscsi/initiatorname.iscsi"

    dinfo "Found iscsi component $1"

    # Check once before getting explicit values, so we can bail out early,
    # e.g. in case of pure-hardware(all-offload) iscsi.
    if ! /sbin/iscsiadm -m session -r "$path" &> /dev/null; then
        return 1
    fi

    if is_ibft "$path"; then
        return
    fi

    # Remove software iscsi cmdline generated by 95iscsi,
    # and let kdump regenerate here.
    rm -f "${initdir}/etc/cmdline.d/95iscsi.conf"

    tgt_name=$(kdump_iscsi_get_rec_val "$path" "node.name")
    tgt_ipaddr=$(kdump_iscsi_get_rec_val "$path" "node.conn\[0\].address")

    # get and set username and password details
    username=$(kdump_iscsi_get_rec_val "$path" "node.session.auth.username")
    [[ $username == "<empty>" ]] && username=""
    password=$(kdump_iscsi_get_rec_val "$path" "node.session.auth.password")
    [[ $password == "<empty>" ]] && password=""
    username_in=$(kdump_iscsi_get_rec_val "$path" "node.session.auth.username_in")
    [[ -n $username ]] && userpwd_str="$username:$password"

    # get and set incoming username and password details
    [[ $username_in == "<empty>" ]] && username_in=""
    password_in=$(kdump_iscsi_get_rec_val "$path" "node.session.auth.password_in")
    [[ $password_in == "<empty>" ]] && password_in=""

    [[ -n $username_in ]] && userpwd_in_str=":$username_in:$password_in"

    kdump_collect_netif_usage "$tgt_ipaddr"

    # prepare netroot= command line
    # FIXME: Do we need to parse and set other parameters like protocol, port
    #        iscsi_iface_name, netdev_name, LUN etc.

    if is_ipv6_address "$tgt_ipaddr"; then
        tgt_ipaddr="[$tgt_ipaddr]"
    fi
    netroot_str="netroot=iscsi:${userpwd_str}${userpwd_in_str}@$tgt_ipaddr::::$tgt_name"

    [[ -f $netroot_conf ]] || touch "$netroot_conf"

    # If netroot target does not exist already, append.
    if ! grep -q "$netroot_str" "$netroot_conf"; then
        echo "$netroot_str" >> "$netroot_conf"
        dinfo "Appended $netroot_str to $netroot_conf"
    fi

    # Setup initator
    if ! initiator_str=$(kdump_get_iscsi_initiator); then
        derror "Failed to get initiator name"
        return 1
    fi

    # If initiator details do not exist already, append.
    if ! grep -q "$initiator_str" "$netroot_conf"; then
        echo "$initiator_str" >> "$netroot_conf"
        dinfo "Appended $initiator_str to $netroot_conf"
    fi
}

kdump_check_iscsi_targets() {
    # If our prerequisites are not met, fail anyways.
    type -P iscsistart > /dev/null || return 1

    kdump_check_setup_iscsi() {
        local _dev
        _dev=$1

        [[ -L /sys/dev/block/$_dev ]] || return
        cd "$(readlink -f "/sys/dev/block/$_dev")" || return 1
        until [[ -d sys || -d iscsi_session ]]; do
            cd ..
        done
        [[ -d iscsi_session ]] && kdump_setup_iscsi_device "$PWD"
    }

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for_each_host_dev_and_slaves_all kdump_check_setup_iscsi
    }
}

# hostname -a is deprecated, do it by ourself
get_alias() {
    local ips
    local entries
    local alias_set

    ips=$(hostname -I)
    for ip in $ips; do
        # in /etc/hosts, alias can come at the 2nd column
        if entries=$(grep "$ip" /etc/hosts | awk '{ $1=""; print $0 }'); then
            alias_set="$alias_set $entries"
        fi
    done

    echo "$alias_set"
}

is_localhost() {
    local hostnames
    local shortnames
    local aliasname
    local nodename=$1

    hostnames=$(hostname -A)
    shortnames=$(hostname -A -s)
    aliasname=$(get_alias)
    hostnames="$hostnames $shortnames $aliasname"

    for name in ${hostnames}; do
        if [[ $name == "$nodename" ]]; then
            return 0
        fi
    done
    return 1
}

# retrieves fence_kdump nodes from Pacemaker cluster configuration
get_pcs_fence_kdump_nodes() {
    local nodes

    pcs cluster sync > /dev/null 2>&1 && pcs cluster cib-upgrade > /dev/null 2>&1
    # get cluster nodes from cluster cib, get interface and ip address
    nodelist=$(pcs cluster cib | xmllint --xpath "/cib/status/node_state/@uname" -)

    # nodelist is formed as 'uname="node1" uname="node2" ... uname="nodeX"'
    # we need to convert each to node1, node2 ... nodeX in each iteration
    for node in ${nodelist}; do
        # convert $node from 'uname="nodeX"' to 'nodeX'
        eval "$node"
        nodename="$uname"
        # Skip its own node name
        if is_localhost "$nodename"; then
            continue
        fi
        nodes="$nodes $nodename"
    done

    echo "$nodes"
}

# retrieves fence_kdump args from config file
get_pcs_fence_kdump_args() {
    if [[ -f $FENCE_KDUMP_CONFIG_FILE ]]; then
        . "$FENCE_KDUMP_CONFIG_FILE"
        echo "$FENCE_KDUMP_OPTS"
    fi
}

get_generic_fence_kdump_nodes() {
    local filtered
    local nodes

    nodes=$(kdump_get_conf_val "fence_kdump_nodes")
    for node in ${nodes}; do
        # Skip its own node name
        if is_localhost "$node"; then
            continue
        fi
        filtered="$filtered $node"
    done
    echo "$filtered"
}

# setup fence_kdump in cluster
# setup proper network and install needed files
kdump_configure_fence_kdump() {
    local kdump_cfg_file=$1
    local nodes
    local args

    if is_generic_fence_kdump; then
        nodes=$(get_generic_fence_kdump_nodes)

    elif is_pcs_fence_kdump; then
        nodes=$(get_pcs_fence_kdump_nodes)

        # set appropriate options in kdump.conf
        echo "fence_kdump_nodes $nodes" >> "${kdump_cfg_file}"

        args=$(get_pcs_fence_kdump_args)
        if [[ -n $args ]]; then
            echo "fence_kdump_args $args" >> "${kdump_cfg_file}"
        fi

    else
        # fence_kdump not configured
        return 1
    fi

    # setup network for each node
    for node in ${nodes}; do
        kdump_collect_netif_usage "$node"
    done

    dracut_install /etc/hosts
    dracut_install /etc/nsswitch.conf
    dracut_install "$FENCE_KDUMP_SEND"
}

# Install a random seed used to feed /dev/urandom
# By the time kdump service starts, /dev/uramdom is already fed by systemd
kdump_install_random_seed() {
    local poolsize

    poolsize=$(< /proc/sys/kernel/random/poolsize)

    if [[ ! -d "${initdir}/var/lib/" ]]; then
        mkdir -p "${initdir}/var/lib/"
    fi

    dd if=/dev/urandom of="${initdir}/var/lib/random-seed" \
        bs="$poolsize" count=1 2> /dev/null
}

kdump_install_systemd_conf() {
    # Kdump turns out to require longer default systemd mount timeout
    # than 1st kernel(90s by default), we use default 300s for kdump.
    if ! grep -q -r "^[[:space:]]*DefaultTimeoutStartSec=" "${initdir}/etc/systemd/system.conf"*; then
        mkdir -p "${initdir}/etc/systemd/system.conf.d"
        echo "[Manager]" > "${initdir}/etc/systemd/system.conf.d/kdump.conf"
        echo "DefaultTimeoutStartSec=300s" >> "${initdir}/etc/systemd/system.conf.d/kdump.conf"
    fi

    # Forward logs to console directly, and don't read Kmsg, this avoids
    # unneccessary memory consumption and make console output more useful.
    # Only do so for non fadump image.
    mkdir -p "${initdir}/etc/systemd/journald.conf.d"
    echo "[Journal]" > "${initdir}/etc/systemd/journald.conf.d/kdump.conf"
    echo "Storage=volatile" >> "${initdir}/etc/systemd/journald.conf.d/kdump.conf"
    echo "ReadKMsg=no" >> "${initdir}/etc/systemd/journald.conf.d/kdump.conf"
    echo "ForwardToConsole=yes" >> "${initdir}/etc/systemd/journald.conf.d/kdump.conf"
}

remove_cpu_online_rule() {
    local file=${initdir}/usr/lib/udev/rules.d/40-redhat.rules

    if [[ -f $file ]]; then
        sed -i '/SUBSYSTEM=="cpu"/d' "$file"
    fi
}

install() {
    declare -A unique_netifs ipv4_usage ipv6_usage
    local arch

    kdump_module_init
    kdump_install_conf
    remove_sysctl_conf

    # Onlining secondary cpus breaks kdump completely on KVM on Power hosts
    # Though we use maxcpus=1 by default but 40-redhat.rules will bring up all
    # possible cpus by default. (rhbz1270174 rhbz1266322)
    # Thus before we get the kernel fix and the systemd rule fix let's remove
    # the cpu online rule in kdump initramfs.
    arch=$(uname -m)
    if [[ "$arch" = "ppc64le" ]] || [[ "$arch" = "ppc64" ]]; then
        remove_cpu_online_rule
    fi

    if is_ssh_dump_target; then
        kdump_install_random_seed
    fi
    dracut_install -o /etc/adjtime /etc/localtime
    inst "$moddir/monitor_dd_progress" "/kdumpscripts/monitor_dd_progress"
    chmod +x "${initdir}/kdumpscripts/monitor_dd_progress"
    inst "/bin/dd" "/bin/dd"
    inst "/bin/tail" "/bin/tail"
    inst "/bin/date" "/bin/date"
    inst "/bin/sync" "/bin/sync"
    inst "/bin/cut" "/bin/cut"
    inst "/bin/head" "/bin/head"
    inst "/bin/awk" "/bin/awk"
    inst "/bin/sed" "/bin/sed"
    inst "/bin/stat" "/bin/stat"
    inst "/sbin/makedumpfile" "/sbin/makedumpfile"
    inst "/sbin/vmcore-dmesg" "/sbin/vmcore-dmesg"
    inst "/usr/bin/printf" "/sbin/printf"
    inst "/usr/bin/logger" "/sbin/logger"
    inst "/usr/bin/chmod" "/sbin/chmod"
    inst "/lib/kdump/kdump-lib-initramfs.sh" "/lib/kdump-lib-initramfs.sh"
    inst "/lib/kdump/kdump-logger.sh" "/lib/kdump-logger.sh"
    inst "$moddir/kdump.sh" "/usr/bin/kdump.sh"
    inst "$moddir/kdump-capture.service" "$systemdsystemunitdir/kdump-capture.service"
    systemctl -q --root "$initdir" add-wants initrd.target kdump-capture.service
    # Replace existing emergency service and emergency target
    cp "$moddir/kdump-emergency.service" "$initdir/$systemdsystemunitdir/emergency.service"
    cp "$moddir/kdump-emergency.target" "$initdir/$systemdsystemunitdir/emergency.target"
    # Also redirect dracut-emergency to kdump error handler
    ln_r "$systemdsystemunitdir/emergency.service" "$systemdsystemunitdir/dracut-emergency.service"

    # Check for all the devices and if any device is iscsi, bring up iscsi
    # target. Ideally all this should be pushed into dracut iscsi module
    # at some point of time.
    kdump_check_iscsi_targets

    kdump_install_systemd_conf

    # nfs/ssh dump will need to get host ip in second kernel and need to call 'ip' tool, see get_host_ip for more detail
    if is_nfs_dump_target || is_ssh_dump_target; then
        inst "ip"
    fi

    kdump_install_net

    # For the lvm type target under kdump, in /etc/lvm/lvm.conf we can
    # safely replace "reserved_memory=XXXX"(default value is 8192) with
    # "reserved_memory=1024" to lower memory pressure under kdump. We do
    # it unconditionally here, if "/etc/lvm/lvm.conf" doesn't exist, it
    # actually does nothing.
    sed -i -e \
        's/\(^[[:space:]]*reserved_memory[[:space:]]*=\)[[:space:]]*[[:digit:]]*/\1 1024/' \
        "${initdir}/etc/lvm/lvm.conf" &> /dev/null

    # Save more memory by dropping switch root capability
    dracut_no_switch_root
}
