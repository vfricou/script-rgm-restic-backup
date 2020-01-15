#!/bin/bash -e

BkpDirectory='/srv/rgm/backup/restic'
BkpRetention='7'
BkpBinary='/usr/local/bin/restic'
ResticVersion='0.9.6'
ResticDlURL="https://github.com/restic/restic/releases/download/v${ResticVersion}/restic_${ResticVersion}_linux_amd64.bz2"
TempWorkDir="/tmp/restic/"

function clean_env() {
    if [ -d ${TempWorkDir} ]; then printf "Cleaning installation environment ${TempWorkDir}\n";rm -rf ${TempWorkDir} ;fi
}

## Main job
# Defining colors scheme
## Foreground
CF_BRED='\033[1;31m'
CF_BGREEN='\033[1;32m'
CF_BYELLOW='\033[1;33m'
## Reset
NC='\033[0m'

while getopts "uci" opt; do
    case ${opt} in
        u)
            printf "${CF_BRED}You've select to uninstall restic binary${NC}\n"
            OPT_Uninstall=true
        ;;
        c)
            printf "${CF_BYELLOW}You've select to clean installation environment${NC}\n"
            OPT_Clean=true
        ;;
        i)
            printf "${CF_BGREEN}You've select to install restic binary${NC}\n"
            OPT_Install=true
        ;;
        \?)
            echo "Option ${opt} not recognized"
            usage
        ;;
    esac
done

if [ ${OPT_Uninstall} ]
then
    del_binary
    clean_env
elif [ ${OPT_Clean} ]
then
    clean_env
elif [ ${OPT_Install} ]
then
    install_restic
else
    echo 'main'
fi