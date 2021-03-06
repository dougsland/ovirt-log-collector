#!/bin/bash -e
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

function usage() {
cat << __EOF__
Usage: $0 <tar-file> <analyzer-working-dir>

Script unpacks sosreport and prepares pg_dump for import.
__EOF__
exit 1;

}

function find_engine_sosreport_dir() {
    for dirname in $(ls -d ${UNPACKED_SOSREPORT}/*/*/)
    do
        # log-collector-data dir keep the hypervisors .tar.xz and pg dump
        if [[ "${dirname}" == *'log-collector-data'* ]]; then
            echo "HYPERVISORS_TARXZ_AND_POSTGRESQL_DATA=${dirname}" >> ${TMP_ROOT}/.metadata-inventory
        else
            echo "ENGINE_UNPACKED_SOSREPORT=${dirname}" >> ${TMP_ROOT}/.metadata-inventory
        fi
    done
}

if [[ $# -lt 2 ]]; then
    usage;
fi

SOS_REPORT=$1
TMP_ROOT=$2

if [[ "$TMP_ROOT" != /* ]]; then
    usage;
fi

UNPACKED_SOSREPORT="$TMP_ROOT/unpacked_sosreport"
PG_DUMP_DIR="$TMP_ROOT/pg_dump_dir"

mkdir -p $UNPACKED_SOSREPORT $PG_DUMP_DIR

echo "Unpacking postgres data. This can take up to several minutes."

tar --exclude='sosreport*/proc' --exclude='sosreport*/dev' --exclude='sosreport*/sys' -C "$UNPACKED_SOSREPORT" -xf "$SOS_REPORT"
chmod -R a+rwx ${UNPACKED_SOSREPORT}

SHA256=$(sha256sum ${1})
LAST_SOSREPORT_EXTRACTED_SHA256SUM=$(echo ${SHA256} | cut -d ' ' -f 1)
LAST_SOSREPORT_EXTRACTED=$(echo ${SHA256} | cut -d ' ' -f 2 | xargs basename)
echo "LAST_SOSREPORT_EXTRACTED=${LAST_SOSREPORT_EXTRACTED}" > ${TMP_ROOT}/.metadata-inventory
echo "LAST_SOSREPORT_EXTRACTED_SHA256SUM=${LAST_SOSREPORT_EXTRACTED_SHA256SUM}" >> ${TMP_ROOT}/.metadata-inventory

find_engine_sosreport_dir

# Parse extra arguments to attach into .metadata-inventory
if [[ ! -z "${3}" ]]; then
    for opt in ${3}; do # Do not use quote here
        echo -e "${opt}" >> "${TMP_ROOT}"/.metadata-inventory
    done
fi

TAR_WITH_POSTGRES_SOSREPORT=$(find "$UNPACKED_SOSREPORT" -name "*postgresql-sosreport*tar.xz")

if [ -z "${TAR_WITH_POSTGRES_SOSREPORT}" ]; then
    echo "Unable to detect postgresql data from sosreport ${1}, aborting.." 1>&2
    rm -rf "${UNPACKED_SOSREPORT} ${PG_DUMP_DIR}"
    exit -1
fi

tar -C "$(dirname $TAR_WITH_POSTGRES_SOSREPORT)" -Jxf "$TAR_WITH_POSTGRES_SOSREPORT"

PG_DUMP_TAR=$(tar tf "$TAR_WITH_POSTGRES_SOSREPORT" | grep "pgdump-scl-rh-postgresql95.tar") || :
if [ ! "${PG_DUMP_TAR}" ]; then
    # Compat mode - old postgresql dumps
    PG_DUMP_TAR=$(tar tf "$TAR_WITH_POSTGRES_SOSREPORT" | grep "pgdump.tar") || :
    if [ ! "${PG_DUMP_TAR}" ]; then
        echo "Unable to detect the database dump from sosreport, aborting.." 1>&2
        rm -rf "${UNPACKED_SOSREPORT} ${PG_DUMP_DIR}"
        exit -1
    fi
fi

echo "PG_DUMP_TAR=${UNPACKED_SOSREPORT}/*/log-collector-data/${PG_DUMP_TAR}" >> ${TMP_ROOT}/.metadata-inventory

tar -Oxf "$TAR_WITH_POSTGRES_SOSREPORT" "$PG_DUMP_TAR" | tar -C "$PG_DUMP_DIR" -x

if [ ! -f "${PG_DUMP_DIR}/restore.sql" ]; then
    echo "Unable to detect restore.sql from ${PG_DUMP_TAR}, aborting.." 1>&2
    rm -rf "${UNPACKED_SOSREPORT} ${PG_DUMP_DIR}"
    exit -1
fi

cd "$PG_DUMP_DIR"
sed -i "s#\\\$\\\$PATH\\\$\\\$#$PWD#g" restore.sql
chmod o+r *
chmod o+rx ./

echo "sos-report extracted into: $UNPACKED_SOSREPORT";
echo "pgdump extracted into: $PG_DUMP_DIR";
