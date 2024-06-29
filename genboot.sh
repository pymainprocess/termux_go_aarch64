#!/bin/bash

base64_code=$(base64 "go1.22.4.linux-arm64.tar.gz")

cdir=$(pwd)

cat <<EOF > ${cdir}/bootstrap.py
import tarfile
import tempfile
import io
import base64
import os

tdir = tempfile.TemporaryDirectory()

t_name = tdir.name

cdir = os.getcwd()

temp = os.path.join(t_name, 'go_content.tar.gz')
out = os.path.join(os.environ.get('HOME'), '.goroot')

if os.path.exists(out):
    os.system("rm -rf " + out)
os.makedirs(out, exist_ok=True)

base64_code = """${base64_code}"""

decoded_bytes = base64.b64decode(base64_code)

bytes_io = io.BytesIO(decoded_bytes)

with open(temp, 'wb') as f:
    f.write(bytes_io.read())

with tarfile.open(temp, 'r:gz') as tar:
    tar.extractall(out)

tdir.cleanup()

with open(os.path.join(os.environ.get('HOME'), '.bashrc'), 'a') as bashrc:
    bashrc.write(". \${HOME}/.goroot/go_loader.env\n")

with open(os.path.join(os.environ.get('HOME'), '.goroot', 'go_loader.env'), 'w') as file:
    file.write("export GOROOT=" + os.path.join(os.environ.get('HOME'), '.goroot') + "\n")
    file.write("export GOPATH=" + os.path.join(os.environ.get('HOME'), '.go') + "\n")
    file.write("export PATH=\$PATH" + ":" + "\${GOROOT}/bin" + ":" + "\${GOPATH}/bin")
EOF

python_kontent=$(cat ${cdir}/bootstrap.py | sed 's/"/\\"/g' | tr -d '\n')

cat <<EOF > bootloader.c
#include <Python.h>
#include <stdio.h>
#include <stdlib.h>

const char *embedded_python_script = "${python_kontent}";

int main(int argc, char *argv[]) {
    Py_Initialize();

    PyRun_SimpleString(embedded_python_script);

    Py_Finalize();

    return 0;
}
EOF

include_flags=$(python3-config --includes)
lib_flags=$(python3-config --ldflags)

if [[ $(dpkg --print-architecture) == "aarch64" ]]; then
    clang -o install-go ${include_flags} ${lib_flags} bootloader.c
fi