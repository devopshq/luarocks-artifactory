# Luarocks repository in JFrog Artifactory
[Jfrog Artifactory] does not support [Luarocks] repository layout yet. This repository adds a workaround to store
luarocks in Artifactory.

It comes in handy if:
- you create Lua modules (*rocks*)
- you can't store them at luarocks.org public repo
- you have an Artifactory instance

## Replicating Luarocks server
Luarocks is a [static HTTP server with index and manifest files]. It's easy to replicate its functions using an 
Artifactory repository with generic layout.

To create or update Luarocks index and manifests, you need to do the following:
1. Create a new repository in Artifactory (for example, `myluarocks.snapshot`).
2. Upload a *rock* to this repository (manually or [via API]).
3. Connect to `myluarocks.snapshot` via [WebDav].
4. Create index and manifest with `luarock-admin make-manifest myluarocks.snapshot`.
5. Wait until Artifactory reindexes the storage (5-15 seconds).

Now you can use `myluarocks.snapshot` as a Luarocks server: 
```bash
luarocks install --server=http://repo.example.com/artifactory/myluarocks.snapshot mypackage
```
**Note:** Our script forces no-dependencies mode for the sake of testing.

If you compile and upload all dependencies to `myluarocks.snapshot`, use `--only-server`:
```bash
luarocks install --only-server=http://repo.example.com/artifactory/myluarocks.snapshot mypackage
```

## Automation
This repository provides a shell script and a Dockerfile to update server manifests and test package installation.

## Installation
We recommend using Docker to keep things isolated and leave your environment untouched.
- Install [Docker]
- Create an Artifactory repo
- Deploy a *rock* for testing

  **Important:** If your artifactory repo does not allow anonymous access, add authentication by modifying curl launch parameters:
  ```bash
  echo "variables = {CURL = \"curl -H 'Authorization: Basic $BASE64_AUTH'\"}" > ~/.luarocks/config-${LUA_VERSION%.*}.lua
  ```
  OR (only with Luarocks 3.1+):
  ```bash
  luarocks config CURL="curl -H 'Authorization: Basic $BASE64_AUTH'"
  ```
- Use this repo to create Luarocks manifests:
```bash
git clone https://gitlab.com/devopshq/luarocks-artifactory.git
cd luarocks-artifactory
docker build -t luarocks-artifactory .
docker run --rm --device /dev/fuse -v "$(pwd)/create-luarocks.sh:/create-luarocks.sh" --privileged luarocks-artifactory sh /create-luarocks.sh http://repo.example.com/artifactory myluarocks.snapshot username:password
luarocks  install --server=http://repo.example.com/artifactory/myluarocks.snapshot mypackage
```

**Important:** Use `USER=root`. See [GitHub issue].

## Usage
```bash
> sh ./create-luarocks.sh --help

Usage:
    create-luarocks.sh ARTIFACTORY_URL REPO USERNAME:PASSWORD [--install-any pkg1 pgk2] [--install-all pkg1 pgk2]
    ARTIFACTORY_URL             URL to Artifactory instance, e.g: https://repo.example.com/artifactory.
    REPOSITORY                  Repository to store rocks and maintain index and manifest.
    USERNAME:PASSWORD           Credentials for user with read, write and remove permissions to this repository (split by colon).
    --install-all pkg1 pgk2     (optional) Try to install all specified packages.
    --install-any pkg1 pgk2     (optional) Try to install any of specified packages.

Examples:
    create-luarocks.sh https://repo.example.com/artifactory myluarocks.snapshot deploy_user:password
    create-luarocks.sh https://repo.example.com/artifactory myluarocks.snapshot deploy_user:password --install-any penlight rapidjson
```

See [GitLab CI example](./.gitlab-ci.yml).

## Scheduler and automation
You can schedule or use [Artifactory WebHook] to automate indexing.



[Jfrog Artifactory]: https://jfrog.com/artifactory
[Luarocks]: https://luarocks.org
[static HTTP server with index and manifest files]: https://github.com/luarocks/luarocks/wiki/Hosting-binary-rocks
[via API]: https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API#ArtifactoryRESTAPI-DeployArtifact
[WebDav]: https://www.jfrog.com/confluence/display/RTF/Using+WebDAV
[Docker]: https://docs.docker.com/install
[GitHub issue]: https://github.com/luarocks/luarocks/issues/901
[Artifactory WebHook]: https://jfrog.com/blog/automation-using-webhooks-in-jfrog-artifactory