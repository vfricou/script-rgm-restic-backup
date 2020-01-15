#!/bin/bash -e

BkpDirectory='/srv/rgm/backup/restic'
BkpRetention='7'
BkpBinary='/usr/local/bin/restic'
ResticVersion='0.9.6'
ResticDlURL="https://github.com/restic/restic/releases/download/v${ResticVersion}/restic_${ResticVersion}_linux_amd64.bz2"
TempWorkDir="/tmp/restic/"