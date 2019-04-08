#!/usr/bin/env bash
set -e
CMDNAME=${0##*/}

echoerr() { echo "$@" 1>&2; }

usage()
{
    cat << USAGE >&2
Usage:
    $CMDNAME ARTIFACTORY_URL REPO USERNAME:PASSWORD --packages PACKAGE1 PACKAGE2
    ARTIFACTORY_URL             URL to Artifactory instance, e.g: https://repo.example.com
    REPOSITORY                  Repository name, where needed create luarocks index and manifest
    USERNAME:PASSWORD           Credential for user with read\write\remove permission, splitted by colon: username:password
    --packages pkg1 pgk2        You can test install your package if needed.

Example:
    $CMDNAME https://repo.example.com myluarocks.snapshot deploy_user:password
USAGE
    exit 1
}

# process arguments
ARTIFACTORY_URL=$1
REPOSITORY=$2
AUTH=$3
LOGIN="${AUTH%:*}"
PASSWORD="${AUTH#*:}"

for PARAM in "$ARTIFACTORY_URL" "$REPOSITORY" "$LOGIN" "$PASSWORD"
do
    if [[ "$PARAM" == "" ]]; then
        echoerr "Error: you need to provide a ARTIFACTORY_URL, REPOSITORY, USERNAME:PASSWORD parameters"
        usage
    fi
done
shift 3

while [[ $# -gt 0 ]]
do
    case "$1" in
        --packages)
        shift 1
        PACKAGES=$@
        break
        ;;
        --help)
        usage
        ;;
        *)
        echoerr "Unknown argument: $1"
        usage
        ;;
    esac
done

create_luarocks(){
    # Use two authentication for Artifactory
    # BASE64 https://www.jfrog.com/confluence/display/RTF/Using+WebDAV#UsingWebDAV-Authenticationfordavfs2Clients
    # davfs2/secrets

    echo "Connect with user $LOGIN"

    # mount point
    mkdir /mnt/$REPOSITORY
    echo $ARTIFACTORY_URL/$REPOSITORY /mnt/$REPOSITORY davfs user,rw,noauto 0 0 >> /etc/fstab

    # secrets and base64
#    mkdir ~/.davfs2
#    BASE64_LOGIN_PASSWORD=`echo $AUTH | openssl enc -base64`
#    echo add_header Authorization \"Basic $BASE64_LOGIN_PASSWORD\" >> ~/.davfs2/davfs2.conf
    echo $ARTIFACTORY_URL/$REPOSITORY $LOGIN $PASSWORD > /etc/davfs2/secrets

    mount /mnt/$REPOSITORY
    ls -la /mnt/$REPOSITORY

    cd /mnt
    set -x
    luarocks-admin make-manifest $REPOSITORY
    set +x
    ls -la /mnt/$REPOSITORY
    umount /mnt/$REPOSITORY
    echo Wait repository update...
    sleep 15
}

install_test(){
    PACKAGES=$1
    for PACKAGE in "$PACKAGES"
    do
        set -x
        luarocks install --only-server=$ARTIFACTORY_URL/$REPOSITORY $PACKAGE
        set +x
    done
}

echo "Create luarocks in $REPOSITORY..."
create_luarocks
echo "DONE"

if [[ "$PACKAGES" != "" ]]; then
    echo "Testing install '$PACKAGES' from $REPOSITORY..."
    install_test $PACKAGES
    echo "DONE"
fi
