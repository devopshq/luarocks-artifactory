FROM alpine

#
# Install Lua: origin https://hub.docker.com/r/abaez/lua/dockerfile
#

ENV LUA_MAJOR_VERSION 5.1
ENV LUA_MINOR_VERSION 5
ENV LUA_VERSION ${LUA_MAJOR_VERSION}.${LUA_MINOR_VERSION}

# Dependencies
RUN apk add --update make tar unzip gcc openssl-dev readline-dev curl libc-dev
RUN apk add ncurses-dev

RUN curl -L http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz | tar xzf -
WORKDIR /lua-$LUA_VERSION

# build lua
RUN make linux test
RUN make install

WORKDIR /

# lua env
ENV WITH_LUA /usr/local/
ENV LUA_LIB /usr/local/lib/lua
ENV LUA_INCLUDE /usr/local/include

RUN rm /lua-$LUA_VERSION -rf

#
# Install Luarocks: origin https://hub.docker.com/r/abaez/luarocks/dockerfile
#
ENV LUAROCKS_VERSION 2.4.2
ENV LUAROCKS_INSTALL luarocks-$LUAROCKS_VERSION
ENV TMP_LOC /tmp/luarocks

# Build Luarocks
RUN curl -OL \
    https://luarocks.org/releases/${LUAROCKS_INSTALL}.tar.gz

RUN tar xzf $LUAROCKS_INSTALL.tar.gz && \
    mv $LUAROCKS_INSTALL $TMP_LOC && \
    rm $LUAROCKS_INSTALL.tar.gz


WORKDIR $TMP_LOC

RUN ./configure \
  --with-lua=$WITH_LUA \
  --with-lua-include=$LUA_INCLUDE \
  --with-lua-lib=$LUA_LIB

RUN make build

RUN make install

WORKDIR /

RUN rm $TMP_LOC -rf

#
# Dependency for luarocks-artifactory
#
RUN apk update
RUN apk add davfs2 openssl vim
