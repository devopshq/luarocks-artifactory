#!/usr/bin/env bash
set -e
CMDNAME=${0##*/}

echoerr() {
  echo "ERROR: $@" 1>&2
}

usage() {
  cat <<USAGE >&2
Usage:
    $CMDNAME ARTIFACTORY_URL REPO USERNAME:PASSWORD [--install-any pkg1 pgk2] [--install-all pkg1 pgk2]
    ARTIFACTORY_URL             URL to Artifactory instance, e.g: https://repo.example.com/artifactory.
    REPOSITORY                  Repository to store rocks and maintain index and manifest.
    USERNAME:PASSWORD           Credentials for user with read, write and remove permissions to this repository (split by colon).
    --install-all pkg1 pgk2     (optional) Try to install all specified packages.
    --install-any pkg1 pgk2     (optional) Try to install any of specified packages.

Examples:
    $CMDNAME https://repo.example.com/artifactory myluarocks.snapshot deploy_user:password
    $CMDNAME https://repo.example.com/artifactory myluarocks.snapshot deploy_user:password --install-any penlight rapidjson
USAGE
  exit 1
}

create_luarocks() {
  # Use Authorization header to authenticate against Artifactory
  # https://www.jfrog.com/confluence/display/RTF/Using+WebDAV#UsingWebDAV-Authenticationfordavfs2Clients
  echo "INFO: Connecting with user $LOGIN"

  # Authentication setup
  # Note: use $(echo -n) to remove newline character. You can also use `base64` command instead of `openssl`
  BASE64_AUTH="$(echo -n $AUTH | openssl enc -base64)"
  echo add_header Authorization \"Basic $BASE64_AUTH\" > ~/.davfs2/davfs2.conf
  echo $ARTIFACTORY_URL/$REPOSITORY $LOGIN $PASSWORD > /etc/davfs2/secrets

  # Mounting DAV storage
  mkdir -p /mnt/$REPOSITORY
  mount -t davfs $ARTIFACTORY_URL/$REPOSITORY /mnt/$REPOSITORY
  sleep 3
  cd /mnt

  echo "INFO: Wait for the files to become available..."
  # If the storage was successfully mounted, lost+found directory is available. In this case, we need to wait until the
  # filesystems are synchronized by interacting with it. If the sync isn't happening in 30 seconds, exit with error
  if [ -d "$REPOSITORY/lost+found" ]; then
    TMP_FILE="$REPOSITORY/$(date +%Y%m%d%H%M%S)"
    COUNTER=0
    touch "$TMP_FILE"
    until [ -f "$TMP_FILE.sha256" ]; do
      if [ $COUNTER -gt 10 ]; then
        echoerr "Something went wrong. Storage wasn't mounted properly"
        exit 1
      fi
      sleep 3
      COUNTER=$((COUNTER + 1))
      echo "DEBUG: Tried $COUNTER time(s)"
    done
    rm -f "$TMP_FILE" "$TMP_FILE.sha256"
  else
    echoerr "Storage wasn't mounted - can't find lost+found directory"
    exit 1
  fi

  luarocks-admin make-manifest $REPOSITORY
  echo "DEBUG: Checking created manifests:"
  ls -la /mnt/$REPOSITORY | grep -E 'manifest|index'
  umount /mnt/$REPOSITORY
  echo "INFO: Waiting for the repository to update..."
  sleep 15
}

test_install_all() {
  local packages="$1"

  for package in $packages; do
    echo "INFO: Trying to install '$package' package"
    luarocks install --only-server=$ARTIFACTORY_URL/$REPOSITORY --deps-mode none $package
  done
}

test_install_any() {
  local packages="$1"

  for package in $packages; do
    echo "INFO: Trying to install '$package' package"
    luarocks install --only-server=$ARTIFACTORY_URL/$REPOSITORY --deps-mode none $package &&
      return 0 ||
      continue
  done

  echoerr "Couldn't install any of the packages: $packages"
  return 11
}

# Parse args
ARTIFACTORY_URL="$1"
REPOSITORY=$2
AUTH="$3"
LOGIN="${AUTH%%:*}"
PASSWORD="${AUTH#*:}"

for PARAM in "$ARTIFACTORY_URL" "$REPOSITORY" "$LOGIN" "$PASSWORD"; do
  if [[ "$PARAM" == "" ]] && [[ "$1" != "--help" ]]; then
    echoerr "You need to provide ARTIFACTORY_URL, REPOSITORY, and USERNAME:PASSWORD parameters"
    usage
  elif [[ "$1" == "--help" ]]; then
    usage
  fi
done
shift 3

while [[ $# -gt 0 ]]; do
  case "$1" in
  --install-all)
    shift 1
    INSTALL_ALL_PACKAGES=$@
    break
    ;;
  --install-any)
    shift 1
    INSTALL_ANY_PACKAGES=$@
    break
    ;;
  *)
    echoerr "Unknown argument: $1"
    usage
    ;;
  esac
done

echo "INFO: Creating luarocks in $REPOSITORY..."
create_luarocks
echo "INFO: DONE"

if [[ ! -z "$INSTALL_ALL_PACKAGES" ]]; then
  echo "INFO: Trying to install ALL packages '$INSTALL_ALL_PACKAGES' from $REPOSITORY..."
  test_install_all "$INSTALL_ALL_PACKAGES"
  echo "INFO: DONE"
fi

if [[ ! -z "$INSTALL_ANY_PACKAGES" ]]; then
  echo "INFO: Trying to install ANY OF '$INSTALL_ANY_PACKAGES' packages from $REPOSITORY..."
  test_install_any "$INSTALL_ANY_PACKAGES"
  echo "INFO: DONE"
fi
