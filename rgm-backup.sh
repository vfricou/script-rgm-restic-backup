#!/bin/bash -e
#
# RGM platform backup script using restic solution
#
# Vincent FRICOU <vincent@fricouv.eu> 2020

# User definitions
BkpDirectory='/srv/rgm/backup/restic'
BkpRetention='7'
BkpBinary='/usr/local/bin/restic'
TempWorkDir="/tmp/restic/"
ResticRepositoryPassLenght='110'
ResticPasswordFile='/root/.restic-repo'
MariaDBClientConf='/root/.my-backup.cnf'

# Constants
ResticVersion='0.9.6'
ResticDlURL="https://github.com/restic/restic/releases/download/v${ResticVersion}/restic_${ResticVersion}_linux_amd64.bz2"

function clean_env() {
    if [ -d ${TempWorkDir} ]; then printf "Cleaning installation environment ${TempWorkDir}\n";rm -rf ${TempWorkDir} ;fi
}

function del_binary() {
    if [ -f ${BkpBinary} ]; then printf "Removing restic binary from system (${BkpBinary})\n";rm ${BkpBinary} ;fi
}

function setup_environment() {
    if [ ! -d ${TempWorkDir} ]; then mkdir -p ${TempWorkDir} ;fi
    if [ ! -d '/usr/local/bin' ]; then mkdir -p '/usr/local/bin' ;fi
    if [ ! -d ${BkpDirectory} ]; then mkdir -p ${BkpDirectory} ;fi
}

function provide_backup_binary() {
    printf "Downloading restic package in version ${ResticVersion}\n"
    wget -q ${ResticDlURL}
    bzip2 -d restic_${ResticVersion}_linux_amd64.bz2
    printf "Installing restic binary in version ${ResticVersion}\n"
    cp restic_${ResticVersion}_linux_amd64 ${BkpBinary}
    chown root:root ${BkpBinary}
    chmod u+x ${BkpBinary}
}

function install_restic() {
    cd ${TempWorkDir}
    provide_backup_binary
    clean_env
}

function generate_repo_password() {
    < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-${ResticRepositoryPassLenght}};echo;
}

function init_restic_repository() {
    if [ -d ${BkpDirectory}/index ]
    then
        printf "${CF_BRED}Restic repository already exist.\nRepository initialization aborted${NC} \n"
        exit 1
    else
        ResticRepoPassword=$(generate_repo_password)
        printf "Generated restic repository password.\n"
        printf "${CF_BRED}Ensure to keep this password preciously !!! ${NC}\n"
        printf "${ResticRepoPassword}\n\n"
        printf "Storing password in restic password-file into ${ResticPasswordFile}.\n"
        echo "${ResticRepoPassword}" > ${ResticPasswordFile}
        ${BkpBinary} --repo ${BkpDirectory} -p ${ResticPasswordFile} init
    fi
}

function perform_mysql_dump() {
    DumpDest="${TempWorkDir}/mariadbdump"
    mkdir ${DumpDest}
    Now="$(date +"%a")"
    Bases="$(mysql --defaults-extra-file=${MariaDBClientConf} -Bse 'show databases')"

    for db in $BASES
    do
        File=${DumpDest}/${db}.${Now}.sql.gz
        mysqldump --compact --order-by-primary --add-drop-table --defaults-extra-file=${MariaDBClientConf} ${db} -R | gzip -9 > ${File}
    done
}

function perform_backups() {
    cd ${TempWorkDir}
    perform_mysql_dump
}

## Main job
# Defining colors scheme
## Foreground
CF_BRED='\033[1;31m'
CF_BGREEN='\033[1;32m'
CF_BYELLOW='\033[1;33m'
## Reset
NC='\033[0m'

while getopts "uciI" opt; do
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
        I)
            printf "${CF_BGREEN}You'll init newer restic repository${NC}\n"
            OPT_Init=true
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
    setup_environment
    install_restic
elif [ ${OPT_Init} ]
then
    init_restic_repository
else
    setup_environment
    perform_backups
    #clean_env
fi