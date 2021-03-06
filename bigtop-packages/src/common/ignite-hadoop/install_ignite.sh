#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to ignite dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/ignite]
     --lib-dir=DIR               path to install ignite home [/usr/lib/ignite]
     --installed-lib-dir=DIR     path where lib-dir will end up on target system
     --bin-dir=DIR               path to install bins [/usr/bin]
     --examples-dir=DIR          path to install examples [doc-dir/examples]
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'doc-dir:' \
  -l 'lib-dir:' \
  -l 'installed-lib-dir:' \
  -l 'bin-dir:' \
  -l 'examples-dir:' \
  -l 'conf-dir:' \
  -l 'build-dir:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
        ;;
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --examples-dir)
        EXAMPLES_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in PREFIX BUILD_DIR ; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
DOC_DIR=${DOC_DIR:-/usr/share/doc/ignite-hadoop}
LIB_DIR=${LIB_DIR:-/usr/lib/ignite-hadoop}
BIN_DIR=${BIN_DIR:-/usr/lib/ignite-hadoop/bin}
ETC_DIR=${ETC_DIR:-/etc/ignite-hadoop}
CONF_DIR=${CONF_DIR:-${ETC_DIR}/conf.dist}

install -d -m 0755 $PREFIX/$LIB_DIR
install -d -m 0755 $PREFIX/$LIB_DIR/libs
install -d -m 0755 $PREFIX/$DOC_DIR
install -d -m 0755 $PREFIX/$BIN_DIR
install -d -m 0755 $PREFIX/$BIN_DIR/include
install -d -m 0755 $PREFIX/$ETC_DIR
install -d -m 0755 $PREFIX/$CONF_DIR
install -d -m 0755 $PREFIX/$MAN_DIR
install -d -m 0755 $PREFIX/var/run/ignite-hadoop/work/

# Pattern matches both ignite-hadoop-*.zip and incubator-ignite-*.zip:
unzip -x $BUILD_DIR/*ignite-*.zip

UNZIP_DIR=*ignite-*/
cp -ar $UNZIP_DIR/libs $PREFIX/$LIB_DIR
cp -a $UNZIP_DIR/config/* $PREFIX/$CONF_DIR
cp -ra $UNZIP_DIR/bin/* $PREFIX/$BIN_DIR

ln -s $ETC_DIR/conf $PREFIX/$LIB_DIR/config
# Create unversioned softlinks to the main libraries
for dir in $PREFIX/$LIB_DIR/libs $PREFIX/$LIB_DIR/libs/ignite-hadoop ; do
  (cd $dir &&
  for j in ignite-*.jar; do
     if [[ $j =~ ignite-(.*)-${IGNITE_HADOOP_VERSION}(.*).jar ]]; then
       name=${BASH_REMATCH[1]}
       ln -s $j ignite-$name.jar
     fi
  done)
done

wrapper=$PREFIX/usr/bin/ignite-hadoop
mkdir -p `dirname $wrapper`
cat > $wrapper <<EOF
#!/bin/bash

BIGTOP_DEFAULTS_DIR=\${BIGTOP_DEFAULTS_DIR-/etc/default}
[ -n "\${BIGTOP_DEFAULTS_DIR}" -a -r \${BIGTOP_DEFAULTS_DIR}/hadoop ] && . \${BIGTOP_DEFAULTS_DIR}/hadoop
[ -n "\${BIGTOP_DEFAULTS_DIR}" -a -r \${BIGTOP_DEFAULTS_DIR}/ignite-hadoop ] && . \${BIGTOP_DEFAULTS_DIR}/ignite-hadoop

exec /usr/lib/ignite-hadoop/bin/include/service.sh \$1 ignite-hadoop
EOF
chmod 755 $wrapper

install -d -m 0755 $PREFIX/usr/bin
