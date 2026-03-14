#!/bin/bash -eu

rm -rf layer/${PYPY_VERSION}
mkdir -p layer/${PYPY_VERSION}
if [[ ${PYPY_VERSION} == pypy3\.* ]]; then
    cp bootstrap.py3 layer/${PYPY_VERSION}/bootstrap
else
    cp bootstrap.py2 layer/${PYPY_VERSION}/bootstrap
fi
chmod +x layer/${PYPY_VERSION}/bootstrap
cd layer
PKG_NAME=${PYPY_VERSION}-linux64
BZIP_FILE=${PKG_NAME}.tar.bz2
if [ ! -f "$BZIP_FILE" ]; then
    curl -OL https://downloads.python.org/pypy/${BZIP_FILE}
fi
cd ${PYPY_VERSION}
tar -xvjf ../${BZIP_FILE}
mv ${PKG_NAME} pypy
zip -r ../../${PYPY_VERSION}.zip .
