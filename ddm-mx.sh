#!/bin/bash

# Exit codes
# 0 - All's well
# 1 - Not root
# 2 - Wrong parameters
# 3 - No driver available
# 4 - Driver not in repository
# 5 - Download error
# 6 - Cannot purge driver
# 7 - Card not supported

# Broadcom hardware list (device ids)
# Update URL: http://linuxwireless.org/en/users/Drivers/b43
# Last update: 13-07-2016
#B43='|4307|4311|4312|4315|4318|4319|4320|4321|4322|4324|432c|4331|4350|4353|4357|43a9|43aa|a8d6|a8d8|a8db|'
#B43LEGACY='|4301|4306|4325|'
#WLDEBIAN='|0576|4313|4328|4329|432a|432b|432d|4358|4359|4365|43a0|435a|4727|a99d|'
#BRCMDEBIAN=''
#UNKNOWN='|4360|43b1|'

###original code from the solydXK project.

####MODIFICATIONS FOR MX by dolphin oracle
##depends: nvidia-detect-mx, nvidia-detect and cli-shell-utils
##modifications assume MX repos for the nvidia drivers
##

#add BitJam's soure cli-shell-utils
source /usr/local/lib/cli-shell-utils/cli-shell-utils.bash

ME=${0##*/}
CLI_PROG="ddm-mx"
LOCK_FILE="/run/lock/$CLI_PROG"
ERR_FILE="/dev/null"

TEXTDOMAINDIR=/usr/share/locale 
export TEXTDOMAIN="ddm-mx"

UNKNOWN_ERROR=$"Unknown Error"
OPTION_ERROR1=$"Option-"
OPTION_ERROR2=$"requires an argument."
RUN_AS_ROOT=$"Run as Root"
INSTALL_DRIVERS_FOR=$"Install drivers for: "
NO_ATI=$"No ATI card found - exiting"
RADEON_DRIVER_NEED=$"Radeon HD %s needs driver %s"



main(){
# -------------------------------------------------------------------------
###file locking
echo "creating lock ..."
trap clean_up EXIT
do_flock 


# --force-yes is deprecated in stretch
FORCE='--force-yes'
source /etc/lsb-release

##commented out for mx 
#if [[ -z "$DISTRIB_RELEASE" ]] || [ "$DISTRIB_RELEASE" -gt 8 ]; then
#  FORCE='--allow-downgrades --allow-remove-essential --allow-change-held-packages'
#fi

# -------------------------------------------------------------------------

BACKPORTS=false
PURGE=''
INSTALL=''
TEST=false
while getopts ":bi:p:ht" opt; do
  case $opt in
#    b)
#      # Backports
#      BACKPORTS=true
#      ;;
    h)
      usage
      exit 0
      ;;
    i)
      # Install
      INSTALL="$INSTALL $OPTARG"
      ;;
    p)
      # Purge
      PURGE="$PURGE $OPTARG"
      ;;
    t)
      # Testing
      TEST=true
      ;;
    \?)
      # Invalid option: start GUI
      #launch_gui $@
      echo $"Invalid Option"
      exit 0
      ;;
    :)
      echo $OPTIONERROR1$OPTARG $OPTION_ERROR2 | tee -a $LOG
      exit 2
      ;;
    *)
      # Unknown error: start GUI
      #launch_gui $@
      echo $"Invalid Option"
      exit 0
      ;;
  esac
done

# Is there anything to do?
if [ "$INSTALL" == "" ]; then
  TEST=false
#  if [ "$PURGE" == "" ]; then
    # Started without anything to install or purge
    #launch_gui $@
#  fi
fi

# From here onward: be root
if [ $UID -ne 0 ]; then
  echo $RUN_AS_ROOT
  exit 1
fi

# If not running in terminal, use GUI frontend
if [ ! -t 1 ]; then
  export DEBIAN_FRONTEND=gnome
fi

# Log file for traceback
MAX_SIZE_KB=5120
LOG_SIZE_KB=0
LOG=/var/log/ddm.log
LOG2=/var/log/ddm.log.1
if [ -f $LOG ]; then
  LOG_SIZE_KB=$(ls -s $LOG | awk '{print $1}')
  if [ $LOG_SIZE_KB -gt $MAX_SIZE_KB ]; then
    mv -f $LOG $LOG2
  fi
fi 

# =========================================================================
# =========================================================================
# =========================================================================
####removed certain options for mx
# Loop through drivers to purge
for DRV in $PURGE; do
  # Start the log
  echo "===================================" | tee -a $LOG
  echo "Purge drivers for: $DRV" | tee -a $LOG
  echo "Start at (m/d/y):" $(date +"%m/%d/%Y %H:%M:%S") | tee -a $LOG
  echo "===================================" | tee -a $LOG
  
  case $DRV in
    ati)
      install_open
      ;;
    nvidia)
      install_open
      ;;
#    broadcom)
#      # If 'purge' is passed as an argument, purge Broadcom
#      echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG
#      #apt-get purge -y $FORCE firmware-b43* 2>&1 | tee -a $LOG
#      apt-get purge -y $FORCE broadcom-sta-dkms 2>&1 | tee -a $LOG
#      #apt-get purge -y $FORCE firmware-brcm80211 2>&1 | tee -a $LOG
#      rm '/etc/modprobe.d/blacklist-broadcom.conf' 2>/dev/null
#      ;;
    open)
      ;;
#    pae)
#      RELEASE=`uname -r`
#      if [[ "$RELEASE" =~ "pae" ]]; then
#	echo "ERROR: Cannot remove PAE kernel when PAE is booted" | tee -a $LOG
#	exit 6
#      else
#	echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG
#	apt-get purge -y $FORCE $(dpkg-query -W -f='${Package}\n' *-pae) 2>&1 | tee -a $LOG
#	echo "PAE kernel successfully removed" | tee -a $LOG
#     fi
#      ;;
    fixbumblebee)
      ;;
    *)
      echo "ERROR: Unknown argument: $DRV"
      echo
      usage
      exit 2
      ;;
  esac
done
####removed certain options for mx
# Loop through drivers to install
for DRV in $INSTALL; do
  # Start the log
  echo "===================================" | tee -a $LOG
  echo $INSTALL_DRIVERS_FOR $DRV | tee -a $LOG
  echo "Start at (m/d/y):" $(date +"%m/%d/%Y %H:%M:%S") | tee -a $LOG
  echo "===================================" | tee -a $LOG
  
  case $DRV in
    ati)
      # Get device ids for Ati
      BCID='1002'
      DEVICEIDS=$(lspci -n -d $BCID: | awk '{print $3}' | cut -d':' -f2)
      
      # Testing
      if $TEST; then
        DEVICEIDS='6649'
      fi

      if [ "$DEVICEIDS" == "" ]; then
	echo $NO_ATI | tee -a $LOG
	exit 0
      fi

      HWCARD=`lspci | grep VGA`
      HWCARD=${HWCARD#*: }
      STARTSERIE=5000
      DRIVER=''
      RADEON=false
      
      # Testing
      if $TEST; then
        HWCARD='00:02.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Bonaire [FirePro W5100]'
      fi
      
      CARD=$(echo "$HWCARD" | egrep -i "radeon\s+[0-9a-z ]+|fire[a-z]+\s+[0-9a-z -]+")
      if [ "$CARD" == "" ]; then
	echo "$HWCARD is not supported" | tee -a $LOG
	exit 7
      fi
      
      if [ "$CARD" != "" ]; then
        DRIVER='fglrx-driver'
        if [[ "$CARD" =~ "HD" ]]; then
	  # Split the card string into separate words and check for the Radeon series
	  OLDIFS=$IFS
	  IFS=" "
	  set $CARD
	  i=0
	  for ITEM
	  do
	    # Is it a number?
	    ITEM=${ITEM:0:4}
	    if [[ "$ITEM" == ?(+|-)+([0-9]) ]]; then
	      echo "$ITEM is number" | tee -a $LOG
	      if [ $ITEM -ge $STARTSERIE ]; then
		echo "Radeon HD $ITEM needs driver $DRIVER" | tee -a $LOG
		break
	      elif [ $ITEM -ge 1000 ] && [ $ITEM -lt $STARTSERIE ]; then
		DRIVER='xserver-xorg-video-radeon'
		RADEON=true
                msg=$(printf "$RADEON_DRIVER_NEED" $ITEM $DRIVER)
		echo $msg | tee -a $LOG
		break
	      fi
	    fi
	    ((i++))
	  done
	  IFS=$OLDIFS
        else
	  echo $CARD $"needs driver" $DRIVER | tee -a $LOG
        fi
      fi

      if [ "$DRIVER" == "" ]; then
	echo $"No driver for this card: " $CARD | tee -a $LOG
	exit 3
      fi

      # Install the AMD/Ati drivers
      install_fglrx $RADEON $DRIVER
      ;;
    nvidia)
      # Bumblebee: https://wiki.debian.org/Bumblebee
      # Get device ids for Nvidia
      BCID='10de'
      DEVICEIDS=$(lspci -n -d $BCID: | awk '{print $3}' | cut -d':' -f2)
      
      # Testing
      if $TEST; then
        DEVICEIDS='0a74'
      fi

      if [ "$DEVICEIDS" == "" ]; then
	echo $"No Nvidia card found - exiting" | tee -a $LOG
	exit 0
      fi

      # Install the Nvidia drivers
      install_nvidia
      ;;
#    broadcom)
#      # Get device ids for Broadcom
#      BCID='14e4'
#      DEVICEIDS=$(lspci -n -d $BCID: | awk '{print $3}' | cut -d':' -f 2)
      
#      # Testing
#      if $TEST; then
#        DEVICEIDS='4313'
#      fi
      
#      if [ "$DEVICEIDS" == "" ]; then
#	echo "No Broadcom device found - exiting" | tee -a $LOG
#	exit 0
#      fi

#      # Install the Broadcom drivers
#      install_broadcom $DEVICEIDS
#     ;;
    open)
      # Install the open drivers
      install_open
      ;;
#    pae)
#      MACHINE=`uname -m`
      
#      if $TEST; then
#        MACHINE='i686'
#      fi
      
      # Install PAE when more than one CPU and not running on 64-bit system
#      if [ $MACHINE == "i686" ]; then
#	apt-get update
#	echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG
#	apt-get install --reinstall -y $FORCE linux-headers-686-pae linux-image-686-pae 2>&1 | tee -a $LOG
#	echo "PAE kernel successfully installed" | tee -a $LOG
 #     else
#	echo "amd64 machine: not installing"
 #     fi
#      ;;
    fixbumblebee)
      # purge nvidia-xconfig and move xorg.conf away
      apt-get purge -y $FORCE nvidia-xconfig 2>&1 | tee -a $LOG
      mv -f /etc/X11/xorg.conf /etc/X11/xorg.conf.ddm 2>&1 | tee -a $LOG
      ;;
    *)
      echo "ERROR: Unknown argument: $DRV"
      echo
      usage
      exit 2
      ;;
  esac
done

exit 0
}

function usage() {
  echo "======================================================================"
  echo "Device Driver Manager Help:"
  echo "======================================================================"
  echo "The following options are allowed:"
  echo
# echo "-b           Use backported packages when available."
  echo
  echo "-i driver    Install given driver."
#  echo "             drivers: ati, nvidia, broadcom, open, pae, fixbumblebee"
  echo "             drivers: ati, nvidia, open, fixbumblebee"
  echo
  echo "-p driver    Purge given driver."
#  echo "             driver: ati, nvidia, broadcom, pae"
  echo "             driver: ati, nvidia"
  echo
  echo "-f           Force DDM to start, even in a Live environment."
  echo
  echo "-t           For development testing only!"
  echo "             This will install drivers for pre-defined hardware."
  echo "             Use with -i."
  echo
  echo "----------------------------------------------------------------------"
#  echo "sudo ddm -i nvidia -i pae -p broadcom"
#  echo "sudo ddm -i \"nvidia pae\" -p broadcom"
#  echo "Both commands install nvidia and pae but purges broadcom."
   echo "sudo ddm-mx -i nvidia"
   echo "sudo ddm-mx -i ati"
  echo "======================================================================"
}

#####removed gui launch
#function launch_gui() {
#  ARGS=$1
#  optimize='OO'; case "$*" in *--debug*) unset optimize; esac
#  MSG='Please enter your password'
#  CMD="python3 -tt${optimize} /usr/lib/ddm/main.py $ARGS"
#  if [ -e "/usr/bin/kdesudo" ]; then
#    kdesudo -i "ddm" -d --comment "<b>$MSG</b>" "$CMD"
#  else
#    gksudo --message "<b>$MSG</b>" "$CMD"
#  fi
#  exit 0
#}



# =========================================================================
# =============================== Functions ===============================
# =========================================================================


####removed backports function for mx
# Create string to install from backports when available
#function get_backports_string() {
#  PCK=$1
#  local BPSTR=''
#  BP=$(grep backports /etc/apt/sources.list | grep -v ^# | awk '{print $3}')
#  if [ "$BP" == "" ]; then
#    BP=$(grep backports /etc/apt/sources.list.d/*.list | grep -v ^# | awk '{print $3}')
#  fi
#  if [ "$BP" != "" ]; then
#    PCKCHK=$(apt-cache madison $PCK | grep "$BP")
#    if [ "$PCKCHK" != "" ]; then
#      BPSTR="-t $BP"
#    fi
#  fi
#  echo $BPSTR
#}

# fglrx -------------------------------------------------------------------------

function preseed_fglrx {
  echo 'libfglrx fglrx-driver/check-for-unsupported-gpu boolean false' | debconf-set-selections
  echo 'fglrx-driver fglrx-driver/check-xorg-conf-on-removal boolean false' | debconf-set-selections
  echo 'libfglrx fglrx-driver/install-even-if-unsupported-gpu-exists boolean false' | debconf-set-selections
  echo 'fglrx-driver fglrx-driver/removed-but-enabled-in-xorg-conf note ' | debconf-set-selections
  echo 'fglrx-driver fglrx-driver/needs-xorg-conf-to-enable note ' | debconf-set-selections
}

function install_fglrx {
  RADEON=$1
  DRIVER=$2
  ARCHITECTURE=$(uname -m)
  CANDIDATE=`env LANG=C apt-cache policy $DRIVER | grep Candidate | awk '{print $2}' | tr -d ' '`
  INSTALLED=`env LANG=C apt-cache policy $DRIVER | grep Installed | awk '{print $2}' | tr -d ' '`

  if [ "$CANDIDATE" == "" ]; then
    exit 4
  fi

  echo "Need driver: $DRIVER ($CANDIDATE)" | tee -a $LOG

####removed backports function for mx  
#  # Backport?
#  BP=''
#  if $BACKPORTS; then
#    BP=$(get_backports_string $DRIVER)
#  fi
  
  # Add additional packages
  if ! $RADEON; then
    DRIVER="$DRIVER fglrx-atieventsd fglrx-control fglrx-modules-dkms libgl1-fglrx-glx"
    if [ "$ARCHITECTURE" == "x86_64" ]; then
      DRIVER="$DRIVER libgl1-fglrx-glx-i386:i386";
    fi
  fi
  
  # In case this is a bybrid (by default installed on SolydXK)
  DRIVER="$DRIVER xserver-xorg-video-intel"
  
echo $"AMD/ATI packages to install are : "$DRIVER

echo -n $"Press <Enter> to continue or CTRL+c to exit"
read x

  # Preseed debconf answers
  preseed_fglrx

  # Install the packages
  apt-get update
  echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG

###removed backports for mx
#  echo "Driver command = apt-get install --reinstall $BP -y $FORCE $DRIVER" | tee -a $LOG
#  apt-get install --reinstall -y $FORCE linux-headers-$(uname -r) build-essential firmware-linux-nonfree amd-opencl-icd 2>&1 | tee -a $LOG
#  apt-get install --reinstall $BP -y $FORCE $DRIVER 2>&1 | tee -a $LOG

  echo "Driver command = apt-get install --reinstall -y $FORCE $DRIVER" | tee -a $LOG
  apt-get install --reinstall -y $FORCE linux-headers-$(uname -r) build-essential firmware-linux-nonfree amd-opencl-icd 2>&1 | tee -a $LOG
  apt-get install --reinstall -y $FORCE $DRIVER 2>&1 | tee -a $LOG
  
  # Configure
  if ! $RADEON; then
    aticonfig --initial -f 2>&1 | tee -a $LOG
  fi

  echo $"Finished" | tee -a $LOG
  
}

# broadcom -------------------------------------------------------------------------

function preseed_broadcom {
  echo 'b43-fwcutter b43-fwcutter/install-unconditional boolean true' | debconf-set-selections
}

function add_broadcom_dependencies {
  DRIVER=$1
  HEADERS="linux-headers-$(uname -r)"
  INSTALLED=`env LANG=C apt-cache policy $HEADERS | grep Installed | awk '{print $2}' | tr -d ' '`
  if [ "$INSTALLED" == "" ]; then
    DRIVER="$DRIVER $HEADER"
  fi
  DEPS=`apt-cache depends $DRIVER | grep Depends: | awk '{print $2}' | sed '/>/d' | tr '\n' ' '`
  DRIVER="$DRIVER $DEPS"
}

function install_broadcom {
  DEVICEIDS=$1
  
  # Get the appropriate driver
  DRIVER=''
  BLACKLIST=''
  MODPROBE=''
  for DID in $DEVICEIDS; do
    if [[ "$B43" =~ "|$DID|" ]] ; then
      DRIVER='firmware-b43-installer'
      MODPROBE='b43'
    elif [[ "$B43LEGACY" =~ "|$DID|" ]] ; then
      DRIVER='firmware-b43legacy-installer'
      MODPROBE='b43legacy'
    elif [[ "$WLDEBIAN" =~ "|$DID|" ]] ; then
      DRIVER='broadcom-sta-dkms'
      BLACKLIST='blacklist b43 brcmsmac bcma ssb'
      MODPROBE='wl'
    elif [[ "$BRCMDEBIAN" =~ "|$DID|" ]] ; then
      DRIVER='firmware-brcm80211'
      MODPROBE='brcmsmac'
    elif [[ "$UNKNOWN" =~ "|$DID|" ]] ; then
      echo "This Broadcom device is not supported: $DID"
    fi
  done
  
  if [ "$DRIVER" != "" ]; then
    # Add the dependencies 
    add_broadcom_dependencies $DRIVER
    
    # Preseed debconf answers
    preseed_broadcom
      
    # Create download directory
    CURDIR=$PWD
    DLDIR='/tmp/dl'
    mkdir -p $DLDIR 2>/dev/null
    cd $DLDIR
    rm -f *.deb 2>/dev/null
    
    # Download the packages
    LIVEDEBS=$(ls /lib/live/mount/medium/offline/broadcom*.deb 2>/dev/null)
    if [ "$LIVEDEBS" != "" ] && [ "$DRIVER" == "broadcom-sta-dkms" ]; then
      cp -v $LIVEDEBS ./ | tee -a $LOG
    else
      # Backport?
      BP=''
      if $BACKPORTS; then
	BP=$(get_backports_string $DRIVER)
      fi
      apt-get update
      echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG
      echo "Broadcom command = apt-get download $BP $DRIVER" | tee -a $LOG
      apt-get download $BP $DRIVER 2>&1 | tee -a $LOG
    fi
    
    # Check if packages were downloaded
    CNT=`ls -1 *.deb 2>/dev/null | wc -l`
    if [ $CNT -eq 0 ]; then
      echo "No packages were downloaded - exiting" | tee -a $LOG
      exit 5
    fi
    
    # Remove modules
    modprobe -rf b44
    modprobe -rf b43
    modprobe -rf b43legacy
    modprobe -rf ssb
    modprobe -rf brcmsmac
    
    # Install the downloaded packages
    dpkg -i *.deb 2>&1 | tee -a $LOG
    
    # Remove download directory
    cd $CURDIR
    rm -r $DLDIR
    
    # Blacklist if needed
    CONF='/etc/modprobe.d/blacklist-broadcom.conf'
    if [ "$BLACKLIST" != "" ]; then
      echo $BLACKLIST > $CONF
    else
      rm -f $CONF 2>/dev/null
    fi
    
    # Start the new driver
    modprobe $MODPROBE

    echo "Broadcomm driver successfully installed" | tee -a $LOG
    
  fi
}

# nvidia -------------------------------------------------------------------------

function preseed_nvidia {
  CANDIDATE=$1
  echo 'nvidia-support nvidia-support/check-xorg-conf-on-removal boolean false' | debconf-set-selections
  echo 'nvidia-support nvidia-support/check-running-module-version boolean true' | debconf-set-selections
  echo 'nvidia-installer-cleanup nvidia-installer-cleanup/delete-nvidia-installer boolean true' | debconf-set-selections
  echo 'nvidia-installer-cleanup nvidia-installer-cleanup/remove-conflicting-libraries boolean true' | debconf-set-selections
  echo "nvidia-support nvidia-support/last-mismatching-module-version string $CANDIDATE" | debconf-set-selections
  echo 'nvidia-support nvidia-support/needs-xorg-conf-to-enable note ' | debconf-set-selections
  echo 'nvidia-support nvidia-support/create-nvidia-conf boolean true' | debconf-set-selections
  echo 'nvidia-installer-cleanup nvidia-installer-cleanup/uninstall-nvidia-installer boolean true' | debconf-set-selections
}

function install_nvidia {
  USER=$(logname)
  ARCHITECTURE=$(uname -m)
  DRIVER=$(nvidia-detect-mx |grep INSTALL: |tr -d ' ' |cut -d ':' -f2)
  
  # Testing
  if $TEST; then
    DRIVER='nvidia-driver'
  fi
  
  CANDIDATE=`env LANG=C apt-cache policy $DRIVER | grep Candidate | awk '{print $2}' | tr -d ' '`
  INSTALLED=`env LANG=C apt-cache policy $DRIVER | grep Installed | awk '{print $2}' | tr -d ' '`

  # Check for Optimus
  OPTIMUS=$(lspci -vnn | grep '\[030[02]\]' | wc -l)
  if [ $OPTIMUS -eq 2 ]; then
    DRIVER='bumblebee-nvidia'
    CANDIDATE=`env LANG=C apt-cache policy $DRIVER | grep Candidate | awk '{print $2}' | tr -d ' '`
    INSTALLED=`env LANG=C apt-cache policy $DRIVER | grep Installed | awk '{print $2}' | tr -d ' '`
  fi


  if [ "$DRIVER" == "" ] || [ "$CANDIDATE" == "" ]; then
    exit 3
  fi

  echo $"Need driver: "$DRIVER "($CANDIDATE)" | tee -a $LOG

####removed backports function for mx  
  # Backport?
#  BP=''
#  if $BACKPORTS; then
#    BP=$(get_backports_string $DRIVER)
#  fi
  
  # Add additional packages


  case $DRIVER in 
                     nvidia-driver)    if [ "$ARCHITECTURE" == "x86_64" ]; then
	                                   # Additional 32-bit drivers for 64-bit systems
	                                   DRIVER="$DRIVER nvidia-settings libgl1-nvidia-glx:i386" 
                                       else
                                           DRIVER="$DRIVER nvidia-settings" 
                                       fi
                                       ;;
        nvidia-legacy-340xx-driver)    if [ "$ARCHITECTURE" == "x86_64" ]; then
                                           DRIVER="$DRIVER nvidia-settings-legacy-340xx libgl1-nvidia-legacy-340xx-glx:i386"
                                       else
                                           DRIVER="$DRIVER nvidia-settings-legacy-340xx"
                                       fi
                                       ;;
        nvidia-legacy-304xx-driver)    if [ "$ARCHITECTURE" == "x86_64" ]; then
                                           DRIVER="$DRIVER nvidia-settings-legacy-304xx libgl1-nvidia-legacy-304xx-glx:i386"
                                       else
                                           DRIVER="$DRIVER nvidia-settings-legacy-304xx"
                                       fi
                                       ;;
                  bumblebee-nvidia)    if [ "$DRIVER" == "bumblebee-nvidia" ]; then
                                       # Bumblebee drivers
                                       DRIVER="$DRIVER primus-libs-ia32:i386 nvidia-settings libgl1-nvidia-glx:i386"
                                       fi
                                       ;;
                                 *)
                                       echo $"ERROR: Unknown argument: " $DRV
                                       echo
                                       usage
                                       exit 2
   esac

####replaced this section with case statement above
#  if [[ "$DRIVER" = "" ]]; then
#    # Legacy drivers
#    DRIVER="$DRIVER nvidia-settings-legacy-304xx"
#    if [ "$ARCHITECTURE" == "x86_64" ]; then
#      DRIVER="$DRIVER libgl1-nvidia-legacy-304xx-glx-i386"
#    fi
#  else
#    if [ "$DRIVER" == "bumblebee-nvidia" ]; then
#      # Bumblebee drivers
#      DRIVER="$DRIVER primus-libs-ia32:i386"
#    else
#      if [ "$ARCHITECTURE" == "x86_64" ]; then
#	# Additional 32-bit drivers for 64-bit systems
#	DRIVER="$DRIVER libgl1-nvidia-glx-i386"
#      fi
#    fi
#    DRIVER="$DRIVER nvidia-settings"
#  fi
  
  # In case this is a bybrid (by default installed on SolydXK)
  DRIVER="$DRIVER xserver-xorg-video-intel"
  
#  # Configuration package
#  DRIVER="$DRIVER nvidia-xconfig"

echo "NVIDIA packages to install are " $DRIVER

echo -n $"Press <Enter> to continue or CTRL+c to exit"
read x
 
  # Preseed debconf answers
  preseed_nvidia $CANDIDATE
  
  # Install the packages
  apt-get update
  echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG

#####removed backports for mx
#  echo "Nvidia command = apt-get install --reinstall $BP -y $FORCE $DRIVER" | tee -a $LOG
#  apt-get install --reinstall -y $FORCE linux-headers-$(uname -r) build-essential firmware-linux-nonfree 2>&1 | tee -a $LOG
#  apt-get install --reinstall $BP -y $FORCE $DRIVER 2>&1 | tee -a $LOG
  
  echo "Nvidia command = apt-get install --reinstall -y $FORCE $DRIVER" | tee -a $LOG
  apt-get install --reinstall -y $FORCE linux-headers-$(uname -r) build-essential firmware-linux-nonfree 2>&1 | tee -a $LOG
  apt-get install --reinstall -y $FORCE $DRIVER 2>&1 | tee -a $LOG
  

# Configure
  if [[ "$DRIVER" =~ "bumblebee-nvidia" ]]; then
    if [ "$USER" != "" ] && [ "$USER" != "root" ]; then
      groupadd bumblebee
      groupadd video
      usermod -a -G bumblebee,video $USER
      #if [ -f /etc/bumblebee/bumblebee.conf ]; then
	#sed -i -e 's/KernelDriver=nvidia\s*$/KernelDriver=nvidia-current/' /etc/bumblebee/bumblebee.conf
      #fi
      service bumblebeed restart
      # Adapt nvidia settings
      if [ -f /usr/lib/nvidia/current/nvidia-settings.desktop ]; then
        sed -i 's/Exec=nvidia-settings/Exec=optirun -b none nvidia-settings -c :8/' /usr/lib/nvidia/current/nvidia-settings.desktop
      fi
      # purge nvidia-xconfig and move xorg.conf away
      apt-get purge -y $FORCE nvidia-xconfig 2>&1 | tee -a $LOG
      mv -f /etc/X11/xorg.conf /etc/X11/xorg.conf.ddm 2>&1 | tee -a $LOG
    else
      echo $"ERROR: Could not configure Bumblebee for user: " $USER | tee -a $LOG
    fi
  else
    nvidia-xconfig 2>/dev/null | tee -a $LOG
  fi
  
  echo $"Finished" | tee -a $LOG
  
}

# open -------------------------------------------------------------------------

function purge_proprietary_drivers {
  rm /etc/X11/xorg.conf 2>/dev/null
  rm /etc/modprobe.d/nvidia* 2>/dev/null
  rm /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null
  # Leave nvidia-detect and nvidia-installer-cleanup
  apt-get purge -y $FORCE $(apt-cache pkgnames | grep nvidia | grep -v detect | grep -v cleanup | cut -d':' -f1) 2>&1 | tee -a $LOG
  apt-get purge -y $FORCE $(apt-cache pkgnames | grep fglrx | cut -d':' -f1) 2>&1 | tee -a $LOG
  apt-get purge -y $FORCE bumblebee* primus* primus*:i386 2>&1 | tee -a $LOG
  
  echo $"Propietary drivers removed" | tee -a $LOG
}

function install_open {
  # Make sure you have the most used drivers installed 
  # These are installed by default on SolydXK
  DRIVER="xserver-xorg-video-nouveau xserver-xorg-video-vesa xserver-xorg-video-intel xserver-xorg-video-fbdev xserver-xorg-video-radeon xserver-xorg-video-ati xserver-xorg-video-nouveau"
  
  # Install the packages
  apt-get update
  echo "Frontend: $(echo $DEBIAN_FRONTEND)" | tee -a $LOG
  echo "Open command = apt-get install --reinstall -y $FORCE $DRIVER" | tee -a $LOG
  apt-get install --reinstall -y $FORCE $DRIVER 2>&1 | tee -a $LOG
  
  echo "Open drivers installed" | tee -a $LOG
  
  # Now cleanup
  purge_proprietary_drivers
}

clean_up()
{
unflock $LOCK_FILE
echo -n $"Press <Enter> to exit"
read x
}

my_exit() {
    local ret=${1:-0}

    # Msg "=> cleaning up"
    exit $ret
}

main "$@"


