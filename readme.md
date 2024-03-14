# ArtifactManger

Artfact Manger is a simplistic software to help you manage your own artifacts (scripts/binaries/important files).
The system is a bit complicated to setup but I try my best to keep it simple for the guide.

## installing on server

-   there needs to be a scripts directory on the server sample:`/var/www/scripts`
    -   the user that connects via ssh needs to have read/write scripts folder to add more and download scripts
    -   permission management is done via the ssh user
-   the script itself needs to be placed in the script directory and needs to be named runner sample:`/var/www/scripts/runner`
-   configure the script
    -   web path sample:`http://server/`
    -   remotepath (script folder) sample:`/var/www/scripts`
    -   make the script executable sample:`/var/www/scripts/runner`

## installing on client

-   configure the script with the variables on top of the script
    -   remote path sample:`/var/www/scripts`
    -   remote user sample:`user@server`
-   install the script via ./artifactManager.sh install afterwards
-   you will need to source the .bashrc afterwards

## usage of the script

To script automatically creates an rss feed for all the artifacts individually. This will allow you to keep track of updates.
The usage of the script is mostly client side and includes downloading, updating and uploading of scripts.

### upload an artifact to the server

`artifactManager.sh upload fileName artifactName`  
`artifactManager.sh upload fileNameAsArtifactName`

### upgrade all locally installed artifacts

`artifactManager.sh update`

### upgrade single installed artifact

`artifactManager.sh update artifactName`
`artifactManager.sh refresh artifactName`

### install an artifact

`artifactManager.sh install artifactName`

### show local version index

`artifactManager.sh list`

### serverside reindex command

`artifactManager.sh reindex`
