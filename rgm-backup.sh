#!/bin/bash -e
#
Version=1.0
Name=rgm-backup.sh
# RGM platform backup script using restic solution
#
# Vincent FRICOU <vincent@fricouv.eu> 2020

# User definitions
BkpTarget='/srv/rgm/backup/restic'
BkpRetention='7' # Correspond to restic snapshots.
BkpBinary='/usr/local/bin/restic'
TempWorkDir="/tmp/restic/"
ResticRepositoryPassLenght='110'
ResticPasswordFile='/root/.restic-repo'
MariaDBClientConf='/root/.my-backup.cnf'
PathToBackup='/etc
/srv
/var
/usr/local/bin/restic
/root/.restic-repo
/root/.my-backup.cnf'

# Constants
ResticVersion='0.9.6'
ResticDlURL="https://github.com/restic/restic/releases/download/v${ResticVersion}/restic_${ResticVersion}_linux_amd64.bz2"
JobLogFile="/srv/rgm/backup/restic-backup_$(date +"%a").log"

function usage() {
    printf "
Usage of script ${Name} (v${Version}) :
Options :
    -h : Display this help
    -i : Perform restic binary installation on system
    -u : Perform restic binary uninstallation on system
    -c : Perform cleaning of temporary directory used to install restic or perform backups
    -I : Initialize new restic repository with password generation.
    -P : Perform repository purge of old snapshots according to retention policy
    -r : Retention policy in days.
"
    exit 128
}

function clean_env() {
    if [ -d ${TempWorkDir} ]; then printf "Cleaning installation environment ${TempWorkDir}\n";rm -rf ${TempWorkDir} ;fi
}

function del_binary() {
    if [ -f ${BkpBinary} ]; then printf "Removing restic binary from system (${BkpBinary})\n";rm ${BkpBinary} ;fi
}

function setup_environment() {
    if [ ! -d ${TempWorkDir} ]; then mkdir -p ${TempWorkDir} ;fi
    if [ ! -d '/usr/local/bin' ]; then mkdir -p '/usr/local/bin' ;fi
    if [ ! -d ${BkpTarget} ]; then mkdir -p ${BkpTarget} ;fi
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

function generate_repo_password() {
    < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-${ResticRepositoryPassLenght}};echo;
}

function init_restic_repository() {
    if [ -d ${BkpTarget}/index ]
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
        ${BkpBinary} --repo ${BkpTarget} -p ${ResticPasswordFile} init
    fi
}

function perform_mysql_dump() {
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Starting mysql dumps\n" | tee -a ${JobLogFile}
    
    DumpDest="${TempWorkDir}/mariadbdump"
    mkdir ${DumpDest}
    Now="$(date +"%a")"
    Bases="$(mysql --defaults-extra-file=${MariaDBClientConf} -Bse 'show databases')"

    for db in $Bases
    do
        File=${DumpDest}/${db}.${Now}.sql.gz
        printf "Dumping database ${db}\n" | tee -a ${JobLogFile}
        mysqldump --defaults-extra-file=${MariaDBClientConf} --compact --order-by-primary --add-drop-table ${db} -R 2>> ${JobLogFile} | gzip -9 > ${File}
    done
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# End mysql dumps\n\n" | tee -a ${JobLogFile}
}

function perform_influxdb_dump() {
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Starting influxdb dumps\n" | tee -a ${JobLogFile}

    DumpDest="${TempWorkDir}/influxdbbackup"
    mkdir ${DumpDest}
    Now="$(date +"%a")"
    Bases="$(influx -precision rfc3339 -execute 'show databases' | grep -ve '^name$' -ve 'name: databases' -ve '----')"
    for db in ${Bases}
    do
        Folder=${DumpDest}/${db}.${Now}
        printf "Dumping database ${db}\n" | tee -a ${JobLogFile}
        influxd backup -database ${db} ${Folder} 1> ${JobLogFile} 2>/dev/null
        tar czf ${Folder}.tar.gz ${Folder}
        rm -rf ${Folder}
    done
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# End influxdb dumps\n\n" | tee -a ${JobLogFile}
}

function upload_mysql_dump() {
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Upload mariadb dumps into restic target start" | tee -a ${JobLogFile}

    ${BkpBinary} --repo ${BkpTarget} -p ${ResticPasswordFile} backup "${TempWorkDir}/mariadbdump" | tee -a ${JobLogFile}
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Upload mariadb dumps into restic target finished\n\n" | tee -a ${JobLogFile}
}

function upload_influx_backup() {
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Upload influx dumps into restic target start" | tee -a ${JobLogFile}

    ${BkpBinary} --repo ${BkpTarget} -p ${ResticPasswordFile} backup "${TempWorkDir}/influxdbbackup" | tee -a ${JobLogFile}
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Upload mariadb dumps into restic target end\n\n" | tee -a ${JobLogFile}
}

function upload_fs_backup() {
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Start fs folder backup" | tee -a ${JobLogFile}

    for fold in ${PathToBackup}
    do
        printf "\nBackup folder ${fold}" | tee -a ${JobLogFile}
        ${BkpBinary} --repo ${BkpTarget} -p ${ResticPasswordFile} --exclude ${BkpTarget} --exclude /var/lib/elasticsearch --exclude /var/lib/mysql --exclude /var/lib/influxdb backup ${fold} | tee -a ${JobLogFile}
    done 
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# End fs folder backup\n\n" | tee -a ${JobLogFile} 
}

function clean_old_repository_files() {
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# Start backup retention cleaning (with retention ${BkpRtention}) \n" | tee -a ${JobLogFile}

    ${BkpBinary} --repo ${BkpTarget} -p ${ResticPasswordFile} forget --keep-daily ${BkpRetention} --prune | tee -a ${JobLogFile}
    printf "####################################\n" | tee -a ${JobLogFile}
    printf "# End backup retention cleaning\n\n" | tee -a ${JobLogFile}

}

## Main job
# Defining colors scheme
## Foreground
CF_BRED='\033[1;31m'
CF_BGREEN='\033[1;32m'
CF_BYELLOW='\033[1;33m'
## Reset
NC='\033[0m'

rm ${JobLogFile}

while getopts "huciIPr:" opt; do
    case ${opt} in
        h)
            usage
        ;;
        u)
            printf "${CF_BRED}You've select to uninstall restic binary${NC}\n" | tee -a ${JobLogFile}
            del_binary
            clean_env
            exit 0
        ;;
        c)
            printf "${CF_BYELLOW}You've select to clean installation environment${NC}\n" | tee -a ${JobLogFile}
            clean_env
            exit 0
        ;;
        i)
            printf "${CF_BGREEN}You've select to install restic binary${NC}\n" | tee -a ${JobLogFile}
            setup_environment
            cd ${TempWorkDir}
            provide_backup_binary
            clean_env
            exit 0
        ;;
        I)
            printf "${CF_BGREEN}You'll init newer restic repository${NC}\n" | tee -a ${JobLogFile}
            init_restic_repository
            exit 0
        ;;
        P)
            printf "${CF_BRED}Perform backup repository old snapshots cleaning${NC}\n" | tee -a ${JobLogFile}
            opt_purge=true
        ;;
        r)
            if [ ${OPTARG} != ${BkpRetention} ];then BkpRetention=${OPTARG} ;fi
        ;;
        \?)
            echo "Option ${opt} not recognized"
            usage
        ;;
    esac
done

if [ ${opt_purge} ];then
    clean_old_repository_files
    exit 0
else
    printf "######################################################\n" | tee ${JobLogFile}
    printf "######################################################\n" | tee -a ${JobLogFile}
    printf "# Startup RGM backup procedure\n" – tee -a ${JobLogFile}
    printf "######################################################\n" | tee -a ${JobLogFile}
    printf "######################################################\n\n" | tee -a ${JobLogFile}
    setup_environment
    cd ${TempWorkDir}
    perform_mysql_dump
    upload_mysql_dump
    perform_influxdb_dump
    upload_influx_backup
    upload_fs_backup
    clean_env
    clean_old_repository_files
    printf "######################################################\n" | tee ${JobLogFile}
    printf "######################################################\n" | tee -a ${JobLogFile}
    printf "# End of RGM backup procedure\n" – tee -a ${JobLogFile}
    printf "######################################################\n" | tee -a ${JobLogFile}
    printf "######################################################\n" | tee -a ${JobLogFile}
fi
# vim: expandtab sw=4 ts=4: