#!/bin/bash
localBin="/home/$(whoami)/.local/artifacts"
#settings
remotePath="/var/www/scripts"
remoteUser="user@server"
webBasePath="http://server/scripts"

flag="$1"
artifactName="$2"
artifactFile="$2"

if [[ "$flag" == 'upload' ]]; then
    if [[ "$3" != "" ]]; then
        artifactName="$3"
    fi

    [ -f "$localBin/index" ] || touch "$localBin/index"

    # scp "$remoteUser:$remotePath/index" "$localBin"
    remoteIndex=$(ssh $remoteUser cat "$remotePath/index")
    artifactAtIndex=$(echo "$remoteIndex" | grep "$artifactName")

    if [[ "$artifactAtIndex" == "" ]]; then
        ssh "$remoteUser" "mkdir $remotePath/$artifactName"
        artifactNewVersion=1
    else
        SAVEIFS=$IFS # Save current IFS
        IFS=' '      # Change IFS to new line
        artifactAsArray=($artifactAtIndex)
        IFS=$SAVEIFS

        artifactVersion="${artifactAsArray[1]}"
        if [[ "$artifactVersion" == "rss.xml" ]]; then
            artifactVersion="${artifactAsArray[2]}"
            echo "$artifactVersion"
        fi
        artifactNewVersion=$((artifactVersion + 1))
        echo "$artifactNewVersion"
    fi
    scp "$artifactFile" "$remoteUser:$remotePath/$artifactName/$artifactNewVersion"
    ssh "$remoteUser" "$remotePath/runner reindex"

elif [[ "$flag" == "reindex" ]]; then
    cd "$remotePath"
    artifactAtDir=$(ls -d */ | sed s/[/]//g)
    SAVEIFS=$IFS # Save current IFS
    IFS=$'\n'    # Change IFS to new line
    artifactAsArray=($artifactAtDir)
    IFS=$SAVEIFS

    >index
    for artifactFolder in "${artifactAsArray[@]}"; do
        cd "$artifactFolder"
        heighestNumber=$(ls | grep -o '[[:digit:]]*' | sort -n | tail -n 1 | xargs)

        # rss begin
        cat >"rss.xml" <<-EOM
<rss version="2.0">
    <channel>
        <title>$artifactFolder</title>
        <description>release feed for $artifactFolder</description>
        <link>$webBasePath/$artifactFolder</link>
        <generator>wallpager</generator>
EOM

        artifactList=$(ls -p | grep -v /)
        SAVEIFS=$IFS # Save current IFS
        IFS=$'\n'    # Change IFS to new line
        releaseArtifacts=($artifactList)
        IFS=$SAVEIFS

        for releaseVersion in "${releaseArtifacts[@]}"; do
            if [[ "$releaseVersion" == "rss.xml" ]]; then
                continue
            fi

            # make iterator over folder content
            cat >>"rss.xml" <<-EOM
        <item>
            <title>$artifactFolder - $releaseVersion </title>
            <description>Release version $releaseVersion of $artifactFolder</description>
            <link>$webBasePath/$artifactFolder/$releaseVersion</link>
        </item>
EOM
        done

        cat >>"rss.xml" <<-EOM
    </channel>
</rss>
EOM
        #rss end

        cd ..
        echo "$artifactFolder $heighestNumber"
        echo "$artifactFolder $heighestNumber" >>index
    done
    echo "server index updated"
elif [[ "$flag" == "install" ]] || [[ "$flag" == "refresh" ]] || [[ "$flag" == "download" ]]; then

    # install artifact
    if [[ "$2" != "" ]]; then
        cd "$localBin"
        artifactToInstall="$2"
        # get index, get current version and dowload to local
        indexContent=$(cat "$localBin/index")
        remoteIndex=$(ssh $remoteUser cat "$remotePath/index")
        artifactDoesNotExist() {
            echo "$artifactToInstall was not found remote"
            exit 1
        }

        echo "$remoteIndex" | grep "$artifactToInstall" || artifactDoesNotExist
        artifactVersion=$(echo "$remoteIndex" | grep "$artifactToInstall" | cut -d ' ' -f 2)
        installedVersion=$(echo "$indexContent" | grep "$artifactToInstall" | cut -d ' ' -f 2)
        locallyInstalled=$(find . -maxdepth 1 -not -type d | sed 's/.\///g' | grep $artifactToInstall || echo "false")
        if [[ "$locallyInstalled" == "false" ]]; then
            echo "dowloading and installing $artifactToInstall@$artifactVersion"
            scp "$remoteUser:$remotePath/$artifactToInstall/$artifactVersion" "$localBin/$artifactToInstall"
            chmod +x "$localBin/$artifactToInstall"
            echo "installed $artifactToInstall@$artifactVersion"
        elif [[ "$installedVersion" == "" ]] || [ "$artifactVersion" -gt "$installedVersion" ]; then
            echo "dowloading and installing $artifactToInstall@$artifactVersion"
            scp "$remoteUser:$remotePath/$artifactToInstall/$artifactVersion" "$localBin/$artifactToInstall"
            chmod +x "$localBin/$artifactToInstall"
            echo "installed $artifactToInstall@$artifactVersion"
        else
            echo "current $installedVersion version already installed"
            exit 0
        fi
        oldVersion="$artifactToInstall $installedVersion"
        newVersion="$artifactToInstall $artifactVersion"
        indexContent=$(echo "$indexContent" | sed "s/$oldVersion/$newVersion/")
        echo "$indexContent" >$localBin/index
    # install script
    else
        localDir='
# adding artifact folder
if [ -d "$HOME/.local/artifacts" ] ; then
    PATH="$HOME/.local/artifacts:$PATH"
fi
'
        if grep -q "# adding artifact folder" "/home/$(whoami)/.bashrc"; then
            echo "artifact manger already installed"
        else
            echo "$localDir" >>"/home/$(whoami)/.bashrc"
            mkdir -p "$localBin"
            cp "$0" "$localBin" && echo "artifact manager install success"
        fi
    fi

elif [[ "$flag" == "update" ]]; then

    artifactToInstall="$2"
    if [[ "$artifactToInstall" != "" ]]; then
        # just use the install which only downloads newer versions
        $0 install "$artifactToInstall"
    else
        cd $localBin
        # get index, get current version and dowload to local
        indexContent=$(cat "$localBin/index")
        echo "getting remote index"
        scp "$remoteUser:$remotePath/index" "$localBin"

        locallyInstalled=$(find . -maxdepth 1 -not -type d | sed 's/.\///g')
        SAVEIFS=$IFS # Save current IFS
        IFS=$'\n'    # Change IFS to new line
        indexArr=($locallyInstalled)
        IFS=$SAVEIFS

        for indexItem in "${indexArr[@]}"; do
            if [[ "$indexItem" == "index" ]]; then
                continue
            fi

            echo "starting update for $indexItem"

            remoteArtifact=$(cat "$localBin/index" | grep "$indexItem")

            if [[ "$remoteArtifact" == "" ]]; then
                echo "no remote artifact $indexItem found current Version is kept"
                echo "upload to artifact for safe keeping or move it to local apps"
            else
                artifactVersion=$(cat "$localBin/index" | grep "$indexItem" | cut -d ' ' -f 2)
                installedVersion=$(echo "$indexContent" | grep "$indexItem" | cut -d ' ' -f 2)
                if [[ "$installedVersion" == "" ]] | [ "$artifactVersion" -gt "$installedVersion" ]; then
                    echo "dowloading and installing $indexItem@$artifactVersion"
                    scp "$remoteUser:$remotePath/$indexItem/$artifactVersion" "$localBin/$indexItem"
                    chmod +x "$localBin/$indexItem"
                    echo "installed $indexItem@$artifactVersion"
                else
                    echo "current version of $indexItem is already installed"
                fi
            fi
        done
    fi

elif [[ "$flag" == "list" ]] || [[ "$flag" == "listpackages" ]]; then
    cat "$localBin/index" | less
fi
