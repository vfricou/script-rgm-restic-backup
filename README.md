# RGM Backup script

This script use [restic](https://restic.net/) as backup solution.  
Is fully designed to perform backup on RGM platform, with standard deployment without any changes in configuration.

## Usage

On RGM deployed platform, you could perform platform backup just simply launch script without any arguments :

```bash
/srv/rgm/backup/rgm-backup.sh
```

## Configuration

By default, the script is configured to use specfic paths in system and all is defined in constant at script beginning :

| Constant name              | Default value                                                                  | Description                                         |
| -------------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------- |
| BkpTarget                  | `/srv/rgm/backup/restic`                                                       | Target where created restic repository              |
| BkpRetention               | `7`                                                                            | Retention in days for backup                        |
| BkpBinary                  | `/usr/local/bin/restic`                                                        | Restic binary location                              |
| TempWorkDir                | `/tmp/restic`                                                                  | Temporary folder used to install and perform backup |
| ResticRepositoryPassLenght | `110`                                                                          | Restic repository default password length           |
| ResticPasswordFile         | `/root/.restic-repo`                                                           | Restic password file used to perform backup         |
| MariaDBClientConf          | `/root/.my-backup.cnf`                                                         | MariaDB Client config file used to perform backup   |
| PathToBackup               | `/etc /srv /var /usr/local/bin/restic /root/.restic-repo /root/.my-backup.cnf` | Path in filesystem backuped by default              |
| ResticVersion              | `0.9.6`                                                                        | Restic version to use                               |
| ResticDlURL                | `<Restic artifact on https://github.com/restic/restic>`                        | Restic download URL                                 |
| JobLogFile                 | `/srv/rgm/backup/restic-backup_$(date +"%a").log`                              | Path for backup log file                            |

## Script arguments

This script as some arguments could used to performs specific actions.

| Args | Usage                                                                 |
| ---- | --------------------------------------------------------------------- |
| -h   | Display script inline help                                            |  
| -i   | Perform restic binary installation from github releases packages      |
| -u   | Uninstall restic from system without removing repository              |
| -c   | Clean temp folder                                                     |
| -I   | Initialize a new repository                                           |
| -P   | Launch a purge into repository to delete snapshots (Use with caution) |
| -r   | Override configured retention policy                                  |

## Licence

BSD

## Author Information

Initial write by Vincent Fricou <vincent@fricouv.eu> (2020) release under the terms of BSD licence.