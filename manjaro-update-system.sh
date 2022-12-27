err() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    RED="${BOLD}\e[1;31m"
	local mesg=$1; shift
	printf "${RED}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

check_pkgs()
{
	local remove=""

    for pkg in ${packages} ; do
        for rmpkg in $(pacman -Qq | grep ${pkg}) ; do
            if [[ "${pkg}" == "${rmpkg}" ]] ; then
               removepkgs="${removepkgs} ${rmpkg}"
            fi
        done
    done

    packages="${removepkgs}"
}

detectDE()
{
    if [[ x"$KDE_FULL_SESSION" = x"true" ]]; then DE=kde;
    elif [[ x"$GNOME_DESKTOP_SESSION_ID" != x"" ]]; then DE=gnome;
    elif `dbus-send --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.gnome.SessionManager > /dev/null 2>&1` ; then DE=gnome;
    elif xprop -root _DT_SAVE_MODE 2> /dev/null | grep ' = \"xfce4\"$' >/dev/null 2>&1; then DE=xfce;
    elif [[ x"$DESKTOP_SESSION" = x"LXDE" ]]; then DE=lxde;
    else DE=""
    fi
}

install_nvidia()
{
    msg "Installing Nvidia drivers for you ..."
    mhwd -a pci nonfree 0300
    mhwd -a pci nonfree 0302
    mhwd -a pci nonfree 0380
}

install_free()
{
    msg "Installing free drivers for you ..."
    mhwd -a pci free 0300
    mhwd -a pci free 0302
    mhwd -a pci free 0380
}

post_upgrade() {
	# init gnupg keyring from scratch
	# before 21.0.6 release all ISOs provided a common private gnupg keys for pacman.
	# we need to have unique on each installation, hence we recreate them from scratch.
	if [[ "$(vercmp $2 20210612)" -lt 0 ]]; then
		msg "Security fix: recreating gnupg keys for pacman"
		printf "    All systems before 21.0.6 release shipped common private keys for pacman!\n    This might take a while to complete ..."
		/usr/bin/rm -rf /etc/pacman.d/gnupg
		/usr/bin/pacman-key --init
		/usr/bin/pacman-key --populate archlinux manjaro
	fi
	
	# enabling os-prober by default
	input="/etc/default/grub"
	checked=false
	msg "Checking for 'os-prober' setup ..."
	var=$(grep "GRUB_DISABLE_OS_PROBER" $input)
        if [[ $var =~ ^GRUB_DISABLE_OS_PROBER=true ]]; then
	      printf "    'os-prober' was already disabled by the user.\n    We don't change those settings.\n"
	      checked=true
	fi    
	if [[ $var =~ ^GRUB_DISABLE_OS_PROBER=false ]]; then
	      printf "    'os-prober' was already enabled by the user.\n"
	      checked=true
	fi
	if [[ $var =~ ^#GRUB_DISABLE_OS_PROBER=false ]]; then
	      printf "    'os-prober' is disabled by default on this system.\n    Your system won't detect other Operating Systems.\n    For enabling it, uncomment the following in '/etc/default/grub':\n    #GRUB_DISABLE_OS_PROBER=false\n"
              checked=true
	fi
	if [[ $checked == false ]]; then
	      printf "    We will reenable 'os-prober' for you ...\n"
	      printf "\n# Uncomment this option to enable os-prober execution in the grub-mkconfig command\n" >> "$input"
	      printf "GRUB_DISABLE_OS_PROBER=false\n" >> "$input"
	      update-grub
	fi	
	# nvidia legacy changes (Dec 2020)
	if [[ "$(pacman -Qq | grep 'mhwd-db' -m1 -x)" == "mhwd-db" ]] && \
        [[ "$(vercmp $(pacman -Q | grep 'mhwd-db ' -m1 | cut -d' ' -f2) 0.6.5-7)" -lt 0 ]]; then
           msg "Checking if MHWD is needing an update ..."
	   rm $(pacman-conf DBPath)db.lck &> /dev/null
	   pacman -Syy &> /dev/null
	   pacman -S mhwd mhwd-db --noconfirm
	fi
	if [[ ! -e /var/lib/mhwd/db/2020-12-30-update ]]; then
        msg "Checking if graphic drivers need an update ..."	   
	install_kernel=false
	# remove EOL kernels first
	if [[ "$(pacman -Qq | grep 'linux57' -m1 -x)" == "linux57" ]]; then
	        msg "Removing EOL kernel 5.7.x"
		pacman -Rcn linux57 --noconfirm
		install_kernel=true
	fi
	if [[ "$(pacman -Qq | grep 'linux58' -m1 -x)" == "linux58" ]]; then
	        msg "Removing EOL kernel 5.8.x"
		pacman -Rcn linux58 --noconfirm
		install_kernel=true
	fi
	if [[ $install_kernel == "true" ]]; then
	if [[ "$(pacman -Qq | grep 'linux54' -m1 -x)" == "linux54" ]]; then
		msg "5.4.x detected. Skipping installing ..."
	else
		msg "Installing 5.4 LTS kernel"
		pacman -S linux54 --noconfirm
	fi
	if [[ "$(pacman -Qq | grep 'linux510' -m1 -x)" == "linux510" ]]; then
		msg "5.10.x detected. Skipping installing ..."
	else
		msg "Installing 5.10 LTS kernel"
		pacman -S linux510 --noconfirm
	fi
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-340xx ]]; then
		msg "Maintaining video driver nvidia-340xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-340xx
		pacman -Rdd $(pacman -Qq | grep 340xx) --noconfirm
		install_free
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-418xx ]]; then
		msg "Maintaining video driver nvidia-418xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-418xx
		pacman -Rdd $(pacman -Qq | grep 418xx) --noconfirm		
		install_nvidia
	fi	
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-430xx ]]; then
		msg "Maintaining video driver nvidia-430xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-430xx
		pacman -Rdd $(pacman -Qq | grep 430xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-435xx ]]; then
		msg "Maintaining video driver nvidia-435xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-435xx
		pacman -Rdd $(pacman -Qq | grep 435xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-440xx ]]; then
		msg "Maintaining video driver nvidia-440xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-440xx
		pacman -Rdd $(pacman -Qq | grep 440xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-450xx ]]; then
		msg "Maintaining video driver nvidia-450xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-450xx
		pacman -Rdd $(pacman -Qq | grep 450xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-nvidia-455xx ]]; then
		msg "Maintaining video driver nvidia-455xx"
		rm -r /var/lib/mhwd/local/pci/video-nvidia-455xx
		pacman -Rdd $(pacman -Qq | grep 455xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-340xx-bumblebee ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-340xx-bumblebee"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-340xx-bumblebee
		pacman -Rdd $(pacman -Qq | grep 340xx) --noconfirm		
		install_free
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-418xx-bumblebee ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-418xx-bumblebee"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-418xx-bumblebee
		pacman -Rdd $(pacman -Qq | grep 418xx) --noconfirm		
		msg "Installing free drivers for you ..."
		install_free
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-430xx-bumblebee ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-430xx-bumblebee"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-430xx-bumblebee
		pacman -Rdd $(pacman -Qq | grep 430xx) --noconfirm			
		msg "Installing free drivers for you ..."
		install_free
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-435xx-prime ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-435xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-435xx-prime
		pacman -Rdd $(pacman -Qq | grep 435xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-440xx-prime ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-440xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-440xx-prime
		pacman -Rdd $(pacman -Qq | grep 440xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-450xx-prime ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-450xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-450xx-prime
		pacman -Rdd $(pacman -Qq | grep 450xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-455xx-prime ]]; then
		msg "Maintaining video driver hybrid-intel-nvidia-455xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-intel-nvidia-455xx-prime
		pacman -Rdd $(pacman -Qq | grep 455xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-435xx-prime ]]; then
		msg "Maintaining video driver hybrid-amd-nvidia-435xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-435xx-prime
		pacman -Rdd $(pacman -Qq | grep 435xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-440xx-prime ]]; then
		msg "Maintaining video driver hybrid-amd-nvidia-440xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-440xx-prime
		pacman -Rdd $(pacman -Qq | grep 440xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-450xx-prime ]]; then
		msg "Maintaining video driver hybrid-amd-nvidia-450xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-450xx-prime
		pacman -Rdd $(pacman -Qq | grep 450xx) --noconfirm		
		install_nvidia
	fi
	if [[ -d /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-455xx-prime ]]; then
		msg "Maintaining video driver hybrid-amd-nvidia-455xx-prime"
		rm -r /var/lib/mhwd/local/pci/video-hybrid-amd-nvidia-455xx-prime
		pacman -Rdd $(pacman -Qq | grep 455xx) --noconfirm		
		install_nvidia
	fi
	touch /var/lib/mhwd/db/2020-12-30-update
	fi
										
	# Revert hardcode fixes before we remove post-upgrade hook r539.f812186-5 upgrade
	if [[ "$(pacman -Qq | grep 'hardcode-fixer' -m1)" == "hardcode-fixer" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'hardcode-fixer' -m1 | cut -d' ' -f2) 1:r539.f812186-5)" -lt 0 ]]; then
		msg "update hardcode-fixer to latest version"
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman --noconfirm -Syy
		pacman -S --noconfirm hardcode-fixer
		msg "revert hardcode-fixer changes"
		export LC_ALL=C
		yes | sudo hardcode-fixer -r
	fi

	# Fix nss 3.51.1-1 upgrade
	if [[ "$(pacman -Qq | grep 'nss' -m1 -x)" == "nss" ]] && \
        [[ "$(vercmp $(pacman -Q | grep 'nss ' -m1 | cut -d' ' -f2) 3.51.1-1)" -lt 0 ]]; then

		msg "Fixing file conflicts for 'nss' update for you ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman -S nss --noconfirm --overwrite /usr/lib\*/p11-kit-trust.so
	fi

	# Fix lib32-nss 3.51.1-1 upgrade
	if [[ "$(pacman -Qq | grep 'lib32-nss' -m1)" == "lib32-nss" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'lib32-nss' -m1 | cut -d' ' -f2) 3.51.1-1)" -lt 0 ]]; then
		msg "Fixing file conflicts for 'lib32-nss' update for you ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman -S lib32-nss --noconfirm --overwrite /usr/lib\*/p11-kit-trust.so
	fi

	# Fix zn_poly 0.9.2-2 upgrade
	if [[ "$(pacman -Qq | grep 'zn_poly' -m1)" == "zn_poly" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'zn_poly' -m1 | cut -d' ' -f2) 0.9.2-2)" -lt 0 ]]; then
		msg "Fixing file conflicts for 'zn_poly' update for you ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman -S zn_poly --noconfirm --overwrite usr/lib/libzn_poly-0.9.so
	fi

	# Fix hplip 3.20.3-2 upgrade
	if [[ "$(pacman -Qq | grep 'hplip' -m1)" == "hplip" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'hplip' -m1 | cut -d' ' -f2) 1:3.20.3-2)" -lt 0 ]]; then
		msg "Fixing file conflicts for 'hplip' update for you ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman -S hplip --noconfirm --overwrite /usr/share/hplip/\*
	fi

	# Fix firewalld 0.8.1-2 upgrade
	if [[ "$(pacman -Qq | grep 'firewalld' -m1)" == "firewalld" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'firewalld' -m1 | cut -d' ' -f2) 0.8.1-2)" -lt 0 ]]; then
		msg "Fixing file conflicts for 'firewalld' update for you ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman -S firewalld --noconfirm --overwrite /usr/lib/python3.8/site-packages/firewall/\*
	fi

	# replace gtk3-classic with regular upstream gtk3 unless reinstalled since m-s 20191208-1
	if [[ "$(vercmp $2 20191208)" -lt 0 ]] && \
		[[ "$(pacman -Qq | grep 'gtk3-classic' -m1)" == "gtk3-classic" ]]; then
		msg "replacing gkt3-classic with regular gtk3 ..."
		msg "If you want to continue using the -classic or -mushroom version please install from the AUR."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman --noconfirm -Syy
		pacman -Rdd --noconfirm gtk3-classic
		pacman -S --noconfirm gtk3
		if [[ "$(pacman -Qq | grep 'lib32-gtk3-classic' -m1)" == "lib32-gtk3-classic" ]]; then
			pacman -Rdd --noconfirm lib32-gtk3-classic
			pacman -S --noconfirm lib32-gtk3
		fi
	fi

	# adjust file permissions for accountsservice >= 0.6.55
	if [[ "$(pacman -Qq | grep 'accountsservice' -m1)" == "accountsservice" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'accountsservice' -m1 | cut -d' ' -f2) 0.6.55-1)" == -1 ]]; then
		msg "adjusting file permissions for Accountsservice 0.6.55 ..."
		chmod 700 /var/lib/AccountsService/users/
		chmod 755 /var/lib/AccountsService/icons/
	fi

	# Fix systemd upgrade with systemd 239.303 installed
	if [[ "$(pacman -Qq | grep 'systemd' -m1)" == "systemd" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'systemd' -m1 | cut -d' ' -f2) 239.6)" -gt 0 ]]; then
		if [[ "$(pacman -Qq | grep 'libidn2' -m1)" == "libidn2" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'libidn2' -m1 | cut -d' ' -f2) 2.1.0-1)" -lt 0 ]]; then
			msg "Your system has an unsupported systemd package. Downgrading it now ..."
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm -Syyuu
		fi
	fi

	# Fix dunst upgrading
	if [[ "$(pacman -Qq | grep 'dunstify' -m1)" == "dunstify" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'dunstify' -m1 | cut -d' ' -f2) 1.3.2-1)" -le 0 ]]; then
		if [[ -e "/usr/bin/dunstify" ]]; then
			msg "Removing 'dunstify' to prepare smooth 'dunst' upgrade ..."
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm -Rdd dunstify
		fi
	fi

	# Fix libutf8proc upgrading
	if [[ "$(pacman -Qq | grep 'libutf8proc' -m1)" == "libutf8proc" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'libutf8proc' -m1 | cut -d' ' -f2) 2.1.1-3)" -le 0 ]]; then
		if [[ -e "/usr/lib/libutf8proc.so.2" ]]; then
			msg "Fix libutf8proc upgrade ..."
			rm -f /usr/lib/libutf8proc.so.2
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm -S libutf8proc
		fi
	fi

	# Fix config issue in sddm.conf
	if [[ "$(vercmp $2 20180513)" -eq 0 ]] && \
		[[ -e "/etc/sddm.conf" ]]; then
		msg "Fix default path config issue in sddm.conf ..."
		cp /etc/sddm.conf /etc/sddm.conf.pacsave
		sed -i -e 's|^.*DefaultPath.*|DefaultPath=/usr/local/sbin:/usr/local/bin:/usr/bin|' /etc/sddm.conf
	fi

	# Fix js52 upgrading
	if [[ "$(pacman -Qq | grep 'js52' -m1)" == "js52" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'js52' -m1 | cut -d' ' -f2) 52.7.3-1)" -le 0 ]]; then
		if [[ -e "/usr/lib/libmozjs-52.so.0" ]]; then
			msg "Fix js52 upgrade ..."
			rm -f /usr/lib/libmozjs-52.so.0
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm -S js52
		fi
	fi

	# Fix Firefox upgrading
	if [[ "$(pacman -Qq | grep 'firefox' -m1)" == "firefox" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'firefox' -m1 | cut -d' ' -f2) 59.0.1-0)" -le 0 ]]; then
		if [[ -e "/usr/lib/firefox/distribution/distribution.ini" ]]; then
			msg "Fix firefox upgrade ..."
			rm -f /usr/lib/firefox/distribution/distribution.ini
		fi
	fi

	# Fix upgrading sddm version is 0.17.0-4 or less
	if [[ "$(pacman -Qq | grep 'sddm' -m1)" == "sddm" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'sddm' -m1 | cut -d' ' -f2) 0.17.0-4)" -le 0 ]]; then
		msg "Fix sddm upgrade ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		if [[ -e "/etc/sddm.conf" ]]; then
			mv /etc/sddm.conf /etc/sddm.backup
		fi
		pacman --noconfirm -S sddm
		if [[ -e "/etc/sddm.conf" ]]; then
			mv /etc/sddm.conf /etc/sddm.conf.pacnew
		fi
		if [[ -e "/etc/sddm.backup" ]]; then
			mv /etc/sddm.backup /etc/sddm.conf
		fi
	fi

	# fix upgrading ca-certificates-utils when version is 20160507-1 or less
	if [[ "$(pacman -Qq | grep 'ca-certificates-utils' -m1)" == "ca-certificates-utils" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'ca-certificates-utils' -m1 | cut -d' ' -f2) 20160507-1)" -le 0 ]]; then
		msg "Fix ca-certificates-utils upgrade ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman --noconfirm -Syw ca-certificates-utils
		rm /etc/ssl/certs/ca-certificates.crt &> /dev/null
		pacman --noconfirm -S ca-certificates-utils
	fi

	# fix issue with xorg-server
	if [[ -L "/usr/lib/xorg/modules/extensions/libglx.xorg" ]]; then
		msg "Removing depreciated libglx.so symlink ..."
		rm /usr/lib/xorg/modules/extensions/libglx.so &> /dev/null
	fi

	# fix upgrading mesa when version is 17.0.1-1 or less
	if [[ "$(pacman -Qq | grep 'mesa' -m1)" == "mesa" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'mesa' -m1 | cut -d' ' -f2) 17.0.1-1)" -le 0 ]]; then
		PKG_LIST="mhwd mesa libglvnd"
		if [[ "$(pacman -Qq | grep 'lib32-mesa' -m1)" == "lib32-mesa" ]] && \
			[[ "$(vercmp $(pacman -Q | grep 'lib32-mesa' -m1 | cut -d' ' -f2) 17.0.1-1)" -le 0 ]]; then
			PKG_LIST="${PKG_LIST} lib32-mesa lib32-libglvnd"
		fi
		msg "Fix mesa-stack ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman --noconfirm -S $PKG_LIST --force
	fi

	# avoid upgrading problems when lib32-libnm-glib46 is installed 
	# and lib32-libnm-glib is not, and we want to install lib32-libnm-glib.
	# ldconfig creates varous symlink in /usr/lib32/ from the lib32-libnm-glib46
	# packages but lib32-libnm-glib provides those files.
	if [[ "$(pacman -Qq | grep 'lib32-libnm-glib' -m1)" != "lib32-libnm-glib" ]]; then
		if [[ "$(pacman -Qq | grep 'lib32-libnm-glib46' -m1)" == "lib32-libnm-glib46" ]]; then
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm --force -S lib32-libnm-glib
		fi
	fi

	# avoid upgrading problems when lib32-libcurl-{gnutls,compat} is
	# installed and lib32-curl is not, and we want to install lib32-curl.
	# ldconfig creates /usr/lib32/libcurl.so.4 from the lib32-libcurl-{gnutls,compat}
	# packages but lib32-curl provides that file.
	if [[ "$(pacman -Qq | grep 'lib32-curl' -m1)" != "lib32-curl" ]]; then
		if [[ "$(pacman -Qq | grep 'lib32-libcurl-gnutls' -m1)" == "lib32-libcurl-gnutls" ]] && \
			[[ "$(vercmp $(pacman -Q | grep 'lib32-libcurl-gnutls' -m1 | cut -d' ' -f2) 7.52.1-1)" -le 0 ]]; then
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm --force -S lib32-curl
		fi
		if [[ "$(pacman -Qq | grep 'lib32-libcurl-compat' -m1)" == "lib32-libcurl-compat" ]] && \
			[[ "$(vercmp $(pacman -Q | grep 'lib32-libcurl-compat' -m1 | cut -d' ' -f2) 7.52.1-1)" -le 0 ]]; then
			rm $(pacman-conf DBPath)db.lck &> /dev/null
			pacman --noconfirm --force -S lib32-curl
		fi
	fi

	# fix upgrading ttf-dejavu when version is 2.35-1 or less
	if [[ "$(pacman -Qq | grep 'ttf-dejavu' -m1)" == "ttf-dejavu" ]] && \
		[[ "$(vercmp $(pacman -Q | grep 'ttf-dejavu' -m1 | cut -d' ' -f2) 2.35-1)" -le 0 ]]; then
		msg "Fix ttf-dejavu upgrade ..."
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman --noconfirm --force -S ttf-dejavu
	fi
	
	# fix xfprogs version
	export LANG=C
	if [[ -n "$(pacman -Qi | grep 'xfsprogs' -m1 | grep Version | grep 1:3)" ]]; then
		rm $(pacman-conf DBPath)db.lck &> /dev/null
		pacman --noconfirm -S xfsprogs
	fi

	# replace dbus-x11 with dbus
	if [[ "$(pacman -Qq | grep 'dbus-x11' -m1)" == "dbus-x11" ]]; then
		if [[ $(pacman -Q manjaro-system | cut -d' ' -f2 | cut -d- -f 1) -le 20221227 ]]; then
			msg "Replacing dbus-x11 with core/dbus\n    If you want to continue using dbus-x11, please install it from the AUR."
			rm $(pacman-conf DBPath)db.lck
			pacman --noconfirm -Rdd dbus-x11
			pacman --noconfirm -S dbus
		fi
	fi
	
	if [[ ! -e $(pacman-conf DBPath)db.lck ]]; then
	    touch $(pacman-conf DBPath)db.lck
	fi
}
