#!/bin/sh
##############################################################################################################
#                                                                                                            #
#         ██████╗███████╗██╗    ██╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗         #
#        ██╔════╝██╔════╝██║    ██║    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗        #
#        ██║     █████╗  ██║ █╗ ██║    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝        #
#        ██║     ██╔══╝  ██║███╗██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗        #
#        ╚██████╗██║     ╚███╔███╔╝    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║        #
#         ╚═════╝╚═╝      ╚══╝╚══╝     ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝        #
#                                                                                                            #
#                           AsusWRT-Merlin CFW Manager For Ubuntu 18.04 LTS                                  #
#                            By Adamm - https://github.com/Adamm00/am_cfwm                                   #
#                                         29/03/2020 - v1.0.0                                                #
##############################################################################################################


clear
sed -n '2,16p' "$0"

#######
### Asuswrt-Merlin.ng build script
### Created By RMerlin, Modified By Adamm
### Expects you to have a copy of the sources at $SRC_LOC
### and model-specific copies as ~/amng.ac86, ~/amng.ac88, etc...
###
### Script will rsync between $SRC_LOC and the various ~/amng.XXX folders
######

sudo true

### Start config

### Manual/hardcoded
# Append git revision
export BUILDREV=1

# Enable update server support (don't use if you build a fork!)
# export MERLINUPDATE=y

# rsync tree from central source tree before build
RSYNC_TREE=y

# Run make clean before build
#CLEANUP_TREE=y


### Uncomment the models you wish to build.

#BAC56=y

# BAC68=y
# BAC87=y

# BAC3200=y

# BAC88=y
# BAC3100=y
# BAC5300=y

# BAC86=y

BAX88=y

# BAX58=y

for model in "$@"; do
	eval "$model=y"
done

if [ "$BAC56" != "y" ] && [ "$BAC68" != "y" ] && [ "$BAC87" != "y" ] && [ "$BAC3200" != "y" ] && [ "$BAC88" != "y" ] && [ "$BAC3100" != "y" ] && [ "$BAC5300" != "y" ] && [ "$BAC86" != "y" ] && [ "$BAX88" != "y" ] && [ "$BAX58" != "y" ]; then
	echo "[*] No Models Selected For Build - Exiting!"
	exit 1
fi

### Paths
# Store built images there
STAGE_LOC="$HOME/images"

# Copy built images there
# Copy is done using scp, so it can be an ssh location
#FINAL_LOC=""
#FINAL_LOC=admin@router.asus.com:/mnt/sda1/Share
FINAL_LOC="admin@192.168.1.69:/share/Storage/Firmware"

# Location of the original source code
SRC_LOC="$HOME/amng"

### End config


build_fw() {
	BRANCH="$3"
	FWMODEL="$2"
	FWPATH="$1"
	localver="$(cat "$SRC_LOC/$FWMODEL.git" 2>/dev/null)"
	remotever="$(git ls-remote https://github.com/RMerl/asuswrt-merlin.ng.git "$BRANCH" | awk '{print $1}')"

	if [ "$localver" != "$remotever" ] || [ "$force" = "y" ]; then
		echo "*** $(date +%R) - Starting building $FWMODEL..."
		cd "$HOME/$FWPATH" || exit 1
		if make "$FWMODEL" > output.txt 2>&1; then
			cd image || exit 1
			if [ "$FWMODEL" = "rt-ac86u" ] || [ "$FWMODEL" = "rt-ax88u" ]; then
				FWNAME=$(find -- *_cferom_ubi.w | head -n 1)
				ZIPNAME="$(echo "$FWNAME" | sed 's~_cferom_ubi.w~~g').zip"
			elif [ "$FWMODEL" = "rt-ax58u" ]; then
				FWNAME=$(find -- *_cferom_pureubi.w | head -n 1)
				ZIPNAME="$(echo "$FWNAME" | sed 's~_cferom_pureubi.w~~g').zip"
			else
				FWNAME=$(find -- *.trx | head -n 1)
				ZIPNAME="$(echo "$FWNAME" | sed 's~.trx~~g').zip"
			fi
			cp "$FWNAME" "$STAGE_LOC/"

			sha256sum "$FWNAME" > sha256sum.sha256
			zip -qj "$STAGE_LOC/$ZIPNAME" "$FWNAME" "$STAGE_LOC/README-merlin.txt" "$STAGE_LOC"/Changelog*.txt "sha256sum.sha256" 2>/dev/null
			echo "*** $(date +%R) - Done building $FWMODEL!"
		else
			echo "!!! $(date +%R) - $FWMODEL build failed!"
		fi
		git -C "$HOME/$FWPATH" rev-parse HEAD > "$SRC_LOC/$FWMODEL.git"
	fi
}

clean_tree() {
	FWPATH=$1
	SDKPATH=$2
	FWMODEL=$3
	BRANCH=$4
	localver="$(cat "$SRC_LOC/$FWMODEL.git" 2>/dev/null)"
	remotever="$(git ls-remote https://github.com/RMerl/asuswrt-merlin.ng.git "$BRANCH" | awk '{print $1}')"

	if [ "$localver" != "$remotever" ] || [ "$force" = "y" ]; then
		echo
		echo "*** $(date +%R) - Cleaning up $FWMODEL..."
		if [ "$RSYNC_TREE" = "y" ]; then
			echo "*** $(date +%R) - Updating $FWMODEL tree..."
			rsync -a --del "$SRC_LOC/" "$HOME/$FWPATH"
		fi
		cd "$HOME/$FWPATH" || exit 1

		CURRENT=$(git branch | grep "\*" | cut -d ' ' -f2)
		if [ "$CURRENT" != "$BRANCH" ] ; then
			git checkout "$BRANCH" >/dev/null 2>&1
			git pull origin "$BRANCH" >/dev/null 2>&1
		fi

		if [ "$CLEANUP_TREE" = "y" ]; then
			cd "$HOME/$FWPATH/$SDKPATH" || exit 1
			make cleankernel clean >/dev/null 2>&1
			rm .config image/*.trx image/*.w >/dev/null 2>&1
		fi

		echo "*** $(date +%R) - $FWMODEL code ready."
	else
		echo "*** $(date +%R) - $FWMODEL Up To Date"
		eval "$(echo "$FWMODEL" | tr -d '-')=n"
	fi
}

# Initial cleanup

echo "--- $(date +%R) - Global cleanup..."
mkdir -p "$STAGE_LOC/backup"
mv "$STAGE_LOC"/* "$STAGE_LOC/backup/" 2>/dev/null
cp "$SRC_LOC/README-merlin.txt" "$STAGE_LOC/"
cp "$SRC_LOC"/Changelog*.txt "$STAGE_LOC/"


# Update all model trees

echo "--- $(date +%R) - Preparing trees"
if [ "$BAC56" = "y" ]; then
	clean_tree amng.ac56 release/src-rt-6.x.4708 rt-ac56u master
fi
if [ "$BAC68" = "y" ]; then
	clean_tree amng.ac68 release/src-rt-6.x.4708 rt-ac68u mainline
fi
if [ "$BAC87" = "y" ]; then
	clean_tree amng.ac87 release/src-rt-6.x.4708 rt-ac87u 384.13_x
fi
if [ "$BAC3200" = "y" ]; then
	clean_tree amng.ac3200 release/src-rt-7.x.main/src rt-ac3200 384.13_x
fi
if [ "$BAC3100" = "y" ]; then
	clean_tree amng.ac3100 release/src-rt-7.14.114.x/src rt-ac3100 mainline
fi
if [ "$BAC88" = "y" ]; then
	clean_tree amng.ac88 release/src-rt-7.14.114.x/src rt-ac88u mainline
fi
if [ "$BAC5300" = "y" ]; then
	clean_tree amng.ac5300 release/src-rt-7.14.114.x/src rt-ac5300 mainline
fi
if [ "$BAC86" = "y" ]; then
	clean_tree amng.ac86 release/src-rt-5.02hnd rt-ac86u mainline
fi
if [ "$BAX88" = "y" ]; then
	clean_tree amng.ax88 release/src-rt-5.02axhnd rt-ax88u ax
fi
if [ "$BAX58" = "y" ]; then
	clean_tree amng.ax58 release/src-rt-5.02axhnd.675x rt-ax58u ax
fi
echo "--- $(date +%R) - All trees ready!"
echo

# Launch parallel builds

echo "--- $(date +%R) - Launching all builds"
if [ "$BAC56" = "y" ]; then
	build_fw amng.ac56/release/src-rt-6.x.4708 rt-ac56u master &
	sleep 20
fi
if [ "$BAC68" = "y" ]; then
	build_fw amng.ac68/release/src-rt-6.x.4708 rt-ac68u mainline &
	sleep 20
fi
if [ "$BAC87" = "y" ]; then
	build_fw amng.ac87/release/src-rt-6.x.4708 rt-ac87u 384.13_x &
	sleep 20
fi
if [ "$BAC3200" = "y" ]; then
	build_fw amng.ac3200/release/src-rt-7.x.main/src rt-ac3200 384.13_x &
	sleep 20
fi
if [ "$BAC3100" = "y" ]; then
	build_fw amng.ac3100/release/src-rt-7.14.114.x/src rt-ac3100 mainline &
	sleep 20
fi
if [ "$BAC88" = "y" ]; then
	build_fw amng.ac88/release/src-rt-7.14.114.x/src rt-ac88u mainline &
	sleep 20
fi
if [ "$BAC5300" = "y" ]; then
	build_fw amng.ac5300/release/src-rt-7.14.114.x/src rt-ac5300 mainline &
	sleep 10
fi
if [ "$BAC86" = "y" ]; then
	build_fw amng.ac86/release/src-rt-5.02hnd rt-ac86u mainline &
	sleep 10
fi
if [ "$BAX88" = "y" ]; then
	build_fw amng.ax88/release/src-rt-5.02axhnd rt-ax88u ax &
	sleep 10
fi
if [ "$BAX58" = "y" ]; then
	build_fw amng.ax58/release/src-rt-5.02axhnd.675x rt-ax58u ax &
	sleep 10
fi

echo "--- $(date +%R) - All builds launched, please wait..."

wait

echo
cd "$STAGE_LOC" || exit 1
{ sha256sum -- *.trx
sha256sum -- *.w; } 2>/dev/null | unix2dos > sha256sums-ng.txt

# Copy everything to the host

if [ -n "$FINAL_LOC" ]; then
	scp -P 4216 -- *.w *.trx "$FINAL_LOC/" 2>/dev/null
fi

echo "=== $(date +%R) - All done!"