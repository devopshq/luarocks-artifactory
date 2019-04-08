# Luarocks package in Jfrog Artifactory
[Jfrog Artifactory](https://jfrog.com/artifactory/) free and commercial versions does not support [luarocks](http://luarocks.org/) repository yet. This repository this functional to Artifactory.

If you want pack and use a `rock`-package, but don't want use luarocks.org by some reason and have Artifactory - use this!

## How it works?
- Luarocks - is [static HTTP server with some index and manifest file](https://github.com/luarocks/luarocks/wiki/Hosting-binary-rocks)
- You create repository `myluarocks.snapshot` in Artifactory
- You upload a `rock` binary file to repository - by hand or API
- Connect to `myluarocks.snapshot` via [WebDav](https://www.jfrog.com/confluence/display/RTF/Using+WebDAV)
- Calculate index and manifest
- For now you can use `myluarocks.snapshot` like luarocks-server: 
```bash
luarocks  install --server=http://repo.example.com/artifactory/myluarocks.snapshot mypackage
```
- If you compile and upload all dependencies to `myluarocks.snapshot`, use `--only-server`:
```bash
luarocks  install --only-server=http://repo.example.com/artifactory/myluarocks.snapshot mypackage
```

## Install
We recommend run scripts in docker - we change some local file and don't remove our line after work (e.g. `/etc/fstab`)
- Install [Docker](https://docs.docker.com/install/)
- Create repo and upload one `mypackage.rock` file for test
- **!!** Add `anonymous` full access to this repo (will be fixed later). `username` and `password` can be empty for now
- Use this scripts for create luarocks:
```bash
git clone https://gitlab.com/devopshq/luarocks-artifactory.git
cd luarocks-artifactory
docker build -t luarocks-artifactory .
docker run --rm --device /dev/fuse -v`pwd`:/src --privileged luarocks-artifactory sh /src/create-luarocks.sh http://repo.example.com/artifactory myluarocks.snapshot username_with_delete_permisstion:password
luarocks  install --server=http://repo.example.com/artifactory/myluarocks.snapshot mypackage
```

Use `USER=root` - https://github.com/luarocks/luarocks/issues/901

## Usage
```bash
> sh ./create-luarocks.sh

Usage:
    .\create-luarocks.sh ARTIFACTORY_URL REPO USERNAME:PASSWORD --packages PACKAGE1 PACKAGE2
    ARTIFACTORY_URL             URL to Artifactory instance, e.g: https://repo.example.com
    REPOSITORY                  Repository name, where needed create luarocks index and manifest
    USERNAME:PASSWORD           Credential for user with read\write\remove permission, splitted by colon: username:passw
ord
    --packages pkg1 pgk2        You can test install your package if needed.

Example:
    .\create-luarocks.sh https://repo.example.com myluarocks.snapshot deploy_user:password
```

## Scheduler and automate
You can schedule or use [Artifactory WebHook](https://jfrog.com/blog/automation-using-webhooks-in-jfrog-artifactory/) to automate indexing.

See [.gitlab-ci.yml](./.gitlab-ci.yml) example
