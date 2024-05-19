#!/bin/bash

#------------------------------------------------------------------------------
#Author: Eugene Wiafe Asiedu

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
function backupredmine(){
    mysqldump redmine > $backupPath/backup.sql

}

function backupconfigfiles(){
    tar -czf $backupPath/backupFile.tar.gz /usr/local/ng-screener/caseManager/config
    /storage/caseManager/attachments /usr/local/ngscreener/caseManager/import_users
}



#function sync(){
    #rsync -avh -e "ssh -p 63022" --owner $backupPath/backup.sql admin@172.30.100.175:$restorePath
    #pass - netguardians
#}

backupredmine
backupconfigfiles
compressArchive
#sync

 
echo
echo '--------------------------------------------------------------------'
echo "[INFO] Backup created : $archiveFilePath"
getArchiveSize
echo '[INFO] Backup Done Successfully'
echo '--------------------------------------------------------------------'
echo