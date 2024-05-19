#!/bin/bash

#------------------------------------------------------------------------------
# Backup ngScreener config
# Usage:
#     backupScript.sh [option] backupFile
# Option:
#     [no option] : backup all config files and DB dump
#     --data      : plus no option, backup logs under /log-collector
# Error Code:
#     0 = OK.
#     1 = Wrong parameters
#     2 = Wrong extension
#     3 = Archive file exists
#     4 = Insufficient space to make the backup
#     5 = Fail to create archive file
#------------------------------------------------------------------------------

storagePath=/storage
option=
archiveFilePath=
archiveDirPath=
archiveFileName=
archiveFileExtension=

function printUsage() {
    echo "Usage:"
    echo "    backupScript.sh [option] backupFile"
    echo "Options:"
    echo "    [no option] : backup all config files and DB dump"
    echo "    --data      : plus no option, backup logs under /log-collector"
    echo "Example"
    echo "    backupScript.sh /tmp/backupFile.tar.gz"
}

function createArchiveFile() {
    mkdir -p $archiveDirPath
    /bin/tar -cf $archiveFileName -P /dev/null

    # Test if file is created
    if [ $? = 0 ]; then
        echo "[INFO] File "$1" created"
    else
        echo "[ERROR] File not created"
        exit 5
    fi
}

function compressArchive() {
        echo "[INFO] Compress archive $archiveFilePath in progress..."
        /bin/gzip $archiveFileName
        /bin/rm -rf $archiveFileName
        echo "[INFO] Compress archive $archiveFilePath : Done"
}

function getArchiveSize() {
  size=`ls -lh $archiveFilePath | awk '{print $5}'`
  echo "[INFO] Backup Size : $size"
}

function checkArchiveFilePath() {
    if [[ "$archiveFileName" == "$archiveFileExtension" ]]; then
        archiveFilePath=$archiveFileName".tar.gz"
        archiveDirPath=`dirname $archiveFilePath`
        archiveFileName=${archiveFilePath%.*}
        archiveFileExtension=${archiveFilePath#*.}
    elif [[ ! "$archiveFileExtension" == "tar.gz" ]]; then
        echo "Extension '$archiveFileExtension' is not supported"
        echo "Supported extensions: tar.gz"
        printf "Would you like to save the archive to $archiveFileName.tar.gz ? [Y/n] "
        read answer
        while true; do
            case $answer in
            "y"|"Y")
                archiveFilePath=$archiveFileName".tar.gz"
                archiveFileName=${archiveFilePath%.*}
                archiveFileExtension=${archiveFilePath#*.}
                echo "Backup will be written to $archiveFilePath"
                break
                ;;
            "n"|"N")
                exit 2
                ;;
            *)
                printf "Would you like to save the archive to $archiveFileName.tar.gz ? [Y/n] "
                read answer
                ;;
            esac
        done
    fi

    if [ -f $archiveFilePath ]; then
        printf "backup: overwrite '$archiveFilePath' ? [Y/n] "
        read answer
        while true ; do
            case $answer in
            "y"|"Y")
                /bin/rm -rf $archiveFilePath
                createArchiveFile
                break
                ;;
            "n"|"N")
                printf "Would you like to define a new path ? [Y/n] "
                read answer
                while true ; do
                    case $answer in
                    "y"|"Y")
                        echo "Define a new path : "
                        read archiveFilePath
                        archiveDirPath=`dirname $archiveFilePath`
                        archiveFileName=${archiveFilePath%.*}
                        archiveFileExtension=${archiveFilePath#*.}
                        checkArchiveFilePath
                        break
                        ;;
                    "n"|"N")
                        exit 3
                        ;;
                    *)
                        printf "Would you like define a new path ? [Y/n] "
                        read answer
                        ;;
                    esac
                done
                break
                ;;
            *)
                printf "backup: overwrite '$archiveFilePath' ? [Y/n] "
                read answer
                ;;
            esac
        done
    else
        createArchiveFile
    fi
}

function checkAvailableSpace() {
    let availableSpace=`/bin/df $archiveDirPath | /bin/awk  '{print $4}' | /bin/sed -n "2 p"`
    let logcollectorUsed=`/bin/df /log-collector | /bin/awk  '{print $3}' | /bin/sed -n "2 p"`
    let percentAvailableSpaceAfterBackup=($availableSpace-$logcollectorUsed)*100/$availableSpace

    if [[ $percentAvailableSpaceAfterBackup -lt 10 ]]; then
        echo "[ERROR] Not enough space in destination partition for backup"
        exit 4
    fi
}

function addMetadata() {
    version=$(ngadmin showDaemonVersion | cut -d"-" -f1)
        echo $version > /tmp/version
        /bin/tar -rf $archiveFileName -P /tmp/version
    /bin/rm -f /tmp/version
}

function backupLogs() {
    for backupFolder in /storage/log-collector /storage/integrity; do
        if [ -d $backupFolder ]; then
            echo "[INFO] Backup $backupFolder in progress..."
            /bin/tar -rf $archiveFileName -P $backupFolder

            if [ $? = 0 ]; then
                echo "[INFO] Backup $backupFolder : Done"
            else
                echo "[ERROR] $backupFolder"
                exit
            fi
        fi
    done
}

function backupDatabase() {
    dbHost=127.0.0.1
    dbPort=3306
    dbFolder=$storagePath/DB

    echo "[INFO] Backup DB ngscreener in progress..."

    # Skip DB backup if mariadb is not available
    mysql_command=`mysql -h $dbHost -P $dbPort -uroot -e "SELECT 1 FROM dual;" 2>/dev/null`
    if [[ $? -ne 0 ]]; then
        echo "WARN: Cannot access to the MariaDB. Skip backing up database."
        return
    fi

    mkdir -p $dbFolder
    /usr/bin/mysqldump -h $dbHost -P $dbPort -u prelude -pprelude_1234 --databases ngscreener > "$dbFolder/ngscreener.sql"
    /bin/tar -rf $archiveFileName -P $dbFolder
    result=$?
    /bin/rm -rf $dbFolder

    if [[ $result -eq 0 ]]; then
        echo "[INFO] Backup DB ngscreener : Done"
    else
        echo "[ERROR] Backup DB ngscreener"
        exit
    fi
}

function backupFile() {
    for file in $@; do
        if [ -e $file ];then
            echo "[INFO] Backup $file in progress..."
            /bin/tar -rf $archiveFileName -P $file
            echo "[INFO] Backup $file : Done"
        else
            echo "[INFO] $file not exists"
        fi
    done
}

function backupSystemFiles() {
    backupFile /etc/hosts
    backupFile /etc/cron.d /etc/cron.daily /etc/cron.deny /etc/cron.hourly /etc/cron.monthly /etc/crontab /etc/cron.weekly
    backupFile /etc/ng-screener /etc/syslog-ng-rules /usr/local/prelude-runtime/etc/prelude-lml/ruleset
    backupFile /usr/local/ng-screener/ngprocessing/ngmesos/etc /usr/local/ng-screener/ngprocessing/ngspark/conf
}

function backupNgadmin() {
    ngadminDirectory=$storagePath/ngadmin

    echo "[INFO] Backup objects using ngadmin in progress..."
    ngadmin forensic_extractFilters -f $ngadminDirectory/forensicFilters

    /bin/tar -rf $archiveFileName -P $ngadminDirectory
    /bin/rm -rf $ngadminDirectory
    echo "[INFO] Backup objects using ngadmin : Done"
}

# ==============================================================================

# Parse parameters
if [ $# -eq 1 ]; then
    archiveFilePath=$1
elif [ $# -eq 2 ]; then
    option=$1
    archiveFilePath=$2
else
    printUsage
    exit 1
fi

archiveDirPath=`dirname $archiveFilePath`
archiveFileName=${archiveFilePath%.*}
archiveFileExtension=${archiveFilePath#*.}

checkArchiveFilePath
if [ "$option" == "--data" ]; then
    checkAvailableSpace
    backupLogs
fi

backupDatabase
backupSystemFiles
backupNgadmin
addMetadata
compressArchive

echo
echo '--------------------------------------------------------------------'
echo "[INFO] Backup created : $archiveFilePath"
getArchiveSize
echo '[INFO] Backup Done Successfully'
echo '--------------------------------------------------------------------'
echo
