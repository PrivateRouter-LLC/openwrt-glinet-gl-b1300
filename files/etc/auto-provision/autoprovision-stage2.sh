#!/bin/sh

# autoprovision stage 2: this script will be executed upon boot if the extroot was successfully mounted (i.e. rc.local is run from the extroot overlay)

. /etc/auto-provision/autoprovision-functions.sh

# Verify we are connected to the Internet
is_connected() {
    ping -q -c3 1.1.1.1 >/dev/null 2>&1
    return $?
}

# Log to the system log and echo if needed
log_say()
{
    echo "${1}"
    logger "${1}"
}

fixPackagesDNS()
{
    log_say "Fixing DNS and installing required packages for opkg"
    # Set our router's dns
    echo "nameserver 1.1.1.1" > /etc/resolv.conf

    log_say "Installing opkg packages"
    opkg --no-check-certificate update
    opkg --no-check-certificate install wget-ssl unzip ca-bundle ca-certificates
    opkg --no-check-certificate install git git-http jq curl unzip
}

installPackages()
{
    signalAutoprovisionWaitingForUser

    until (opkg update)
     do
        log_say "opkg update failed. No internet connection? Retrying in 15 seconds..."
        sleep 15
    done

    signalAutoprovisionWorking

    log_say "Autoprovisioning stage2 is about to install packages"

    # switch ssh from dropbear to openssh (needed to install sshtunnel)
    #opkg remove dropbear
    #opkg install openssh-server openssh-sftp-server sshtunnel

    #/etc/init.d/sshd enable
    #mkdir /root/.ssh
    #chmod 0700 /root/.ssh
    #mv /etc/dropbear/authorized_keys /root/.ssh/
    #rm -rf /etc/dropbear
    # CUSTOMIZE
    sed -i '/v2raya/d' /etc/opkg/customfeeds.conf
    # install some more packages that don't need any extra steps
   log_say "updating all packages!"

   log_say "                                                                      "
   log_say " ███████████             ███                         █████            "
   log_say "░░███░░░░░███           ░░░                         ░░███             "
   log_say " ░███    ░███ ████████  ████  █████ █████  ██████   ███████    ██████ "
   log_say " ░██████████ ░░███░░███░░███ ░░███ ░░███  ░░░░░███ ░░░███░    ███░░███"
   log_say " ░███░░░░░░   ░███ ░░░  ░███  ░███  ░███   ███████   ░███    ░███████ "
   log_say " ░███         ░███      ░███  ░░███ ███   ███░░███   ░███ ███░███░░░  "
   log_say " █████        █████     █████  ░░█████   ░░████████  ░░█████ ░░██████ "
   log_say "░░░░░        ░░░░░     ░░░░░    ░░░░░     ░░░░░░░░    ░░░░░   ░░░░░░  "
   log_say "                                                                      "
   log_say "                                                                      "
   log_say " ███████████                        █████                             "
   log_say "░░███░░░░░███                      ░░███                              "
   log_say " ░███    ░███   ██████  █████ ████ ███████    ██████  ████████        "
   log_say " ░██████████   ███░░███░░███ ░███ ░░░███░    ███░░███░░███░░███       "
   log_say " ░███░░░░░███ ░███ ░███ ░███ ░███   ░███    ░███████  ░███ ░░░        "
   log_say " ░███    ░███ ░███ ░███ ░███ ░███   ░███ ███░███░░░   ░███            "
   log_say " █████   █████░░██████  ░░████████  ░░█████ ░░██████  █████           "
   log_say "░░░░░   ░░░░░  ░░░░░░    ░░░░░░░░    ░░░░░   ░░░░░░  ░░░░░            "

   opkg update
   ## INSTALL MESH  ##
    opkg update
      ## INSTALL MESH PROFILE ##
    log_say "Installing Mesh Packages..."
    opkg install tgrouterappstore luci-app-shortcutmenu luci-app-poweroff luci-app-wizard
    opkg remove wpad-mbedtls wpad-basic-mbedtls wpad-basic wpad-basic-openssl wpad-basic-wolfssl wpad-wolfssl
    opkg install wpad-mesh-openssl kmod-batman-adv batctl avahi-autoipd mesh11sd batctl-full luci-app-dawn git jq
    opkg install luci-app-easymesh luci-mod-dashboard tgwireguard tgopenvpn luci-app-poweroff luci-lib-ipkg lua luci
    opkg install luci-proto-batman-adv luci-theme-argon luci-app-argon-config tgrouterappstore libiwinfo-lua libubus-lua
    opkg install base-files busybox cgi-io dropbear firewall
    opkg install luci-mod-admin-full luci-mod-network luci-mod-status luci-mod-system



  log_say "PrivateRouter update complete!"
}

autoprovisionStage2()
{
    log_say "Autoprovisioning stage2 speaking"

    # TODO this is a rather sloppy way to test whether stage2 has been done already, but this is a shell script...
    if [ $(uci get system.@system[0].log_type) == "file" ]; then
        log_say "Seems like autoprovisioning stage2 has been done already. Running stage3."
        #/root/autoprovision-stage3.py
    else
        signalAutoprovisionWorking

  echo "nameserver 1.1.1.1" > /etc/resolv.conf
	log_say "Updating system time using ntp; otherwise the openwrt.org certificates are rejected as not yet valid."
        ntpd -d -q -n -p 0.openwrt.pool.ntp.org

        # CUSTOMIZE: with an empty argument it will set a random password and only ssh key based login will work.
        # please note that stage2 requires internet connection to install packages and you most probably want to log in
        # on the GUI to set up a WAN connection. but on the other hand you don't want to end up using a publically
        # available default password anywhere, therefore the random here...
        #setRootPassword ""

        installPackages

        chmod +x ${overlay_root}/etc/rc.local
        cat >${overlay_root}/etc/rc.local <<EOF
chmod a+x /etc/stage3.sh
bash /etc/stage3.sh || exit 1
EOF

        mkdir -p /var/log/archive

        # logrotate is complaining without this directory
        mkdir -p /var/lib

        uci set system.@system[0].log_type=file
        uci set system.@system[0].log_file=/var/log/syslog
        uci set system.@system[0].log_size=0

        uci commit
        sync
        reboot
    fi
}

# Check and wait for Internet connection
while ! is_connected; do
    log_say "Waiting for Internet connection..."
    sleep 1
done
log_say "Internet connection established"

fixPackagesDNS

autoprovisionStage2
