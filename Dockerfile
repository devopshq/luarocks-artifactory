FROM alpine:3.12

# Lua original Dockerfile https://hub.docker.com/r/abaez/lua/dockerfile
ENV LUA_VERSION 5.4.3

# LuaRocks original Dockerfile https://hub.docker.com/r/abaez/luarocks/dockerfile
ENV LUAROCKS_VERSION 3.7.0

# Basic runtime + luarocks-artifactory dependencies
RUN apk add --no-cache \
    curl \
    davfs2 \
    ncurses-dev \
    openssl \
    readline-dev \
    unzip

# Build and install lua tools
ARG PREFIX=/usr/local/
ARG LUA_LIB=${PREFIX}/lib/lua
ARG LUA_INCLUDE=${PREFIX}/include
RUN mkdir -p /tmp/lua && cd /tmp/lua && \
    apk add --no-cache --virtual .tmp-build \
        make \
        tar \
        openssl-dev \
        gcc \
        libc-dev && \
    # Get Packages
    curl -SsL https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz | tar xzf - && \
    curl -SsL https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz | tar xzf - && \
    cd lua-${LUA_VERSION} && \
    # Build Lua
    make linux test && \
    make install && \
    cd ../luarocks-${LUAROCKS_VERSION} && \
    # Build LuaRocks
    ./configure \
        --with-lua=${PREFIX} \
        --with-lua-include=${LUA_INCLUDE} \
        --with-lua-lib=${LUA_LIB} && \
    make build && \
    make install && \
    # Cleanup
    rm -rf /tmp/lua && \
    apk del .tmp-build && \
    # Create directories
    mkdir -p ~/.davfs2 ~/.luarocks
