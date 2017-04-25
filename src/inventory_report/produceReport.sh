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
DB_NAME="report";
SOS_REPORT_UNPACK_DIR=$1
PSQL="psql --quiet --tuples-only --no-align --dbname $DB_NAME --username engine --host $PGRUN"

# PKI
ENGINE_PKI_CONF_DIR="/etc/ovirt-engine/engine.conf.d"
ENGINE_PKI_FILE="10-setup-pki.conf"
ENGINE_PKI_SETTINGS="${ENGINE_PKI_CONF_DIR}/${ENGINE_PKI_FILE}"
DEFAULT_PKI_TRUSTSTORE="/etc/pki/ovirt-engine/.truststore"

function printUsage() {
cat << __EOF__
Usage: $0 <analyzer_working_dir> <csv|adoc>

Script generates from db adoc or csv file describing current system.
__EOF__

}

function initDbVariables() {
    DBDIR=$SOS_REPORT_UNPACK_DIR/postgresDb

    PGDATA=$DBDIR/pgdata
    PGRUN=$DBDIR/pgrun
}

function execute_SQL_from_file() {
    ${PSQL} --file "$1";
}

function executeSQL() {
    ${PSQL} --command "$1";
}

function cleanup_db() {
    execute_SQL_from_file sqls/cleanup.sql &> /dev/null
}

function bulletize() {
    if [ -n "${ADOC}" ]; then
        sed "s/^/* /"
    else
        sed "s/^//"
    fi
}

function enumerate() {
    if [ -n "${ADOC}" ]; then
        sed "s/^/. /"
    else
        sed "s/^//"
    fi
}

function createStatementExportingToCsvFromSelect() {
    echo "Copy ($1) To STDOUT With CSV DELIMITER E'$2' HEADER;"
}

function printTable() {
    executeSQL "$(createStatementExportingToCsvFromSelect "$1" "$SEPARATOR_FOR_COLUMNS")" | createAsciidocTableWhenProducingAsciidoc
}

#function you can pipe output into, and which rearrange data to produce asciidoc table.
function createAsciidocTableWhenProducingAsciidoc() {
    if [ -n "${ADOC}" ]; then
        echo "[options=\"header\"]"
        echo "|===="

        while read A; do echo $SEPARATOR_FOR_COLUMNS$A;done
        echo "|===="
    else
        while read A; do echo $A;done

    fi
}

function projectionCountingRowsWithOrder() {
    if [ $# -eq 0 ]; then
        #coding error
        exit 1
    fi
    echo "row_number() OVER (ORDER BY $@ NULLs last) AS \"NO.\" "

}

function printSection() {
    echo
    if [ -n "${ADOC}" ]; then
        echo "== $1"
    else
        echo "# $1"
    fi
}

function printFileHeader() {
    if [ -n "${ADOC}" ]; then
        echo '
= oVirt Report
:doctype: book
:source-highlighter: coderay
:listing-caption: Listing
:pdf-page-size: A4

++++
<link rel="stylesheet"  href="http://cdnjs.cloudflare.com/ajax/libs/font-awesome/3.1.0/css/font-awesome.min.css">
++++

:toc:
:toc-placement: preamble
:icons: font
:sectnums:
    ';
    else
        echo "# oVirt Report"
    fi
}

function initNetworksTableQuery() {
    local queryNetworksUsingNetworkAttachments="SELECT
          $(projectionCountingRowsWithOrder vs.vds_name, n.name),
          n.name AS \"Network\",
          vs.vds_name AS \"Host Name\",
          sp.name AS \"Data Center\",
          nic.name AS \"Nic Name\",
          CASE
            WHEN
              nic.is_bond
            THEN
              (
                SELECT 'Bond(slaves: '||string_agg(slave.name, ', ')||')'
                FROM vds_interface slave
                WHERE slave.bond_name = nic.name AND slave.vds_id=nic.vds_id
              )
            WHEN
              n.vlan_id IS NOT NULL
            THEN
              'Vlan'
            ELSE
               'Regular Nic'
          END AS \"Attached To Nic Type\",

          na.address AS \"Ipv4 Address\",
          n.vlan_id AS \"Vlan ID\"

        FROM
          network n
          LEFT OUTER JOIN storage_pool sp on n.storage_pool_id = sp.id
          LEFT OUTER JOIN network_attachments na on n.id = na.network_id
          LEFT OUTER JOIN vds_interface nic on na.nic_id = nic.id
          LEFT OUTER JOIN vds_static vs on nic.vds_id = vs.vds_id
          ORDER BY vs.vds_name, n.name";

    local queryNetworksNotUsingNetworkAttachments="SELECT
      $(projectionCountingRowsWithOrder vs.vds_name, n.name),
      n.name AS \"Network\",
      vs.vds_name AS \"Host Name\",
      sp.name AS \"Data Center\",
      nic.name AS \"Attached to Nic\",

      CASE
        WHEN
          nic.is_bond
        THEN
          (
            SELECT 'Bond(slaves:'||string_agg(slave.name, ', ')||')'
            FROM vds_interface slave
            WHERE slave.bond_name = nic.name AND slave.vds_id=nic.vds_id
          )
        WHEN
          n.vlan_id IS NOT NULL
        THEN
          'Vlan'
        ELSE
           'Regular Nic'
      END \"Nic Type\",

      n.addr AS \"Ipv4 Address\",
      n.vlan_id AS \"Vlan ID\"
    FROM
      network n
      LEFT OUTER JOIN storage_pool sp on n.storage_pool_id = sp.id
      LEFT OUTER JOIN vds_interface nic on n.name = nic.network_name
      LEFT OUTER JOIN vds_static vs on nic.vds_id = vs.vds_id
      ORDER BY vs.vds_name, n.name";

    if [ "$NETWORK_ATTACHMENTS_TABLE_EXISTS" = "exists" ]; then
        NETWORKS_TABLE_QUERY=$queryNetworksUsingNetworkAttachments;
    else
        NETWORKS_TABLE_QUERY=$queryNetworksNotUsingNetworkAttachments;
    fi

}

function initVariablesForVaryingNamesInSchema() {
    CLUSTER_TABLE=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM   information_schema.tables WHERE  table_name = 'vds_groups')) WHEN TRUE then 'vds_groups' else 'cluster' END AS name;" )
    NETWORK_ATTACHMENTS_TABLE_EXISTS=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM   information_schema.tables WHERE  table_name = 'network_attachments')) WHEN TRUE then 'exists' else 'does not exist' END AS name;")
    CLUSTER_PK_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vds_groups' AND column_name='vds_group_id')) WHEN TRUE then 'vds_group_id' else 'cluster_id' END AS name;" )
    VDS_CLUSTER_FK_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vds' AND column_name='vds_group_id')) WHEN TRUE THEN 'vds_group_id' else 'cluster_id' END AS name;" )
    VMS_CLUSTER_FK_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vms' AND column_name='vds_group_id')) WHEN TRUE THEN 'vds_group_id' else 'cluster_id' END AS name;" )
    VMS_CLUSTER_COMPATIBILITY_VERSION_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vms' AND column_name='vds_group_compatibility_version')) WHEN TRUE THEN 'vds_group_compatibility_version' else 'cluster_compatibility_version' END AS name;" )
    VDS_AGENT_IP_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vds' AND column_name='agent_ip')) WHEN TRUE THEN 'agent_ip' else 'ip' END AS name;" )

    initNetworksTableQuery
}
#-----------------------------------------------------------------------------------------------------------------------

initDbVariables

if [ $# -ne 2 ]; then
    printUsage
    exit 1
fi

if [ $2 = "csv" ]; then
    SEPARATOR_FOR_COLUMNS=,;
elif [ $2 = "adoc" ]; then
    ADOC=1;
    SEPARATOR_FOR_COLUMNS=\|;
else
    printUsage
    exit 1
fi

# Make sure nothing was left behind in case an exception happen during runtime
cleanup_db

execute_SQL_from_file sqls/hosts_create_related_lookup_tables.sql
execute_SQL_from_file sqls/storage_create_related_lookup_tables.sql
initVariablesForVaryingNamesInSchema

printFileHeader

printSection "Pre-upgrade checks:"
echo "- List of hosts for health check:"
execute_SQL_from_file sqls/hosts_query_check_health.sql

pki_file_path=$(find "${SOS_REPORT_UNPACK_DIR}" -name ${ENGINE_PKI_FILE})
if [[ $? != 0 ]]; then
    echo "Could not find ${ENGINE_PKI_FILE} in the sosreport, exiting"
    exit $?
fi
dir_pki_conf=$(dirname "${pki_file_path}")

# Read the variables from conf files in /etc/ovirt-engine/engine.conf.d
for file in ${dir_pki_conf}/*.conf
do
    [ -f "$file" ] && source $file
done

if [ ! -z "${ENGINE_PKI_TRUST_STORE}" ] && [ "${ENGINE_PKI_TRUST_STORE}" != ${DEFAULT_PKI_TRUSTSTORE} ]; then
    echo
    echo "- PKI Trust Store:"
    echo "CAUTION: ENGINE_PKI_TRUST_STORE has non-default value"
    echo "ENGINE_PKI_TRUST_STORE defaults to ${DEFAULT_PKI_TRUSTSTORE}"
    echo "ENGINE_PKI_TRUST_STORE is currently ${ENGINE_PKI_TRUST_STORE}"
    echo
    echo "To change this value, use the files in ${ENGINE_PKI_CONF_DIR}"
    echo
    echo "For more information about this topic, see also:"
    echo "https://bugzilla.redhat.com/1336838"
fi

printSection "Engine details"
echo ".≈ version of initially installed engine footnote:[<actually version of first update script>]"
executeSQL "SELECT regexp_replace( (SELECT version FROM schema_version ORDER BY version ASC LIMIT 1), '^(\d{2})(\d{2}).*$', '\1.\2' );"
echo

echo ".≈ current engine version footnote:[<actually version of last update script>]"
executeSQL "SELECT regexp_replace( (SELECT version FROM schema_version ORDER BY version DESC LIMIT 1), '^(\d{2})(\d{2}).*$', '\1.\2' );"
echo

echo ".Engine FQDN";
find "${SOS_REPORT_UNPACK_DIR}" -name "10-setup-protocols.conf" -exec grep "ENGINE_FQDN" '{}' \; | sed "s/^.*=//"
echo

printSection " Data Centers"
executeSQL "SELECT
                name AS \"Data Center\"
            FROM storage_pool
            ORDER BY name;" | enumerate

printSection " Clusters"
printTable "SELECT
              $(projectionCountingRowsWithOrder c.name),
              c.name  AS \"Cluster Name\",
              sp.name AS \"Data Center Name\",
              c.compatibility_version AS \"Compatibility Version\"
            FROM
              $CLUSTER_TABLE c
              LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id=sp.id
            ORDER BY c.name"

printSection " Hosts"
QUERY_HOSTS="SELECT
     $(projectionCountingRowsWithOrder c.name, v.vds_name),
     v.vds_name AS \"Name of Host\",
     coalesce(htt.text, 'Unknown (id='||v.vds_type||')') AS \"Host Type\",
     c.name AS \"Cluster\",
     c.name AS \"Data Center\",
     v.$VDS_AGENT_IP_COLUMN,
     v.host_name AS \"Host Name\",
     v.rpm_version AS \"Rpm Version\",
     v.kvm_version AS \"Kvm Version\",
     v.libvirt_version AS \"Libvirt Version\",
     v.spice_version AS \"Spice Version\",
     v.kernel_version AS \"Kernel Version\",
     hst.text AS \"Status\",
     v.host_os AS \"Operating System\",
     v.vm_count AS \"Vm Count\",
     v.mem_available \"Available memory\"
   FROM
     vds v
     JOIN $CLUSTER_TABLE c ON c.$CLUSTER_PK_COLUMN=v.$VDS_CLUSTER_FK_COLUMN
     LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id = sp.id
     LEFT OUTER JOIN host_status_temp hst ON hst.id = v.status
     LEFT OUTER JOIN host_type_temp htt ON htt.id = v.vds_type
   ORDER BY
     c.name, v.vds_name";
QUERY_HOSTS_AS_CSV=$(createStatementExportingToCsvFromSelect "$QUERY_HOSTS" "$SEPARATOR_FOR_COLUMNS")

executeSQL "$QUERY_HOSTS_AS_CSV" | createAsciidocTableWhenProducingAsciidoc;

printSection " Storage Domains"

QUERY_STORAGE_DOMAIN="SELECT
      $(projectionCountingRowsWithOrder sds.storage_name),
      sds.storage_name AS \"Storage Domain\",
      stt.text AS \"Type\",
      sdtt.text AS \"Storage Domain Type\"
    FROM storage_domains sds
    JOIN storage_type_temp stt ON sds.storage_type=stt.id
    JOIN storage_domain_type_temp sdtt ON sds.storage_domain_type=sdtt.id
    ORDER BY sds.storage_name"

QUERY_STORAGE_DOMAIN_AS_CSV=$(createStatementExportingToCsvFromSelect "$QUERY_STORAGE_DOMAIN" "$SEPARATOR_FOR_COLUMNS")

executeSQL "$CREATE_TEMP_TABLES_SQL $QUERY_STORAGE_DOMAIN_AS_CSV" | createAsciidocTableWhenProducingAsciidoc;

printSection "DWH"
printTable "SELECT
(SELECT replace(replace(var_value::varchar,'1','Yes'),'0','No') FROM dwh_history_timekeeping
WHERE
var_name = 'DwhCurrentlyRunning') AS \"DWH running\",
(SELECT var_value FROM dwh_history_timekeeping
WHERE
  var_name = 'dwhHostname') AS \"Host Name\""

printSection "Networks"
printTable "$NETWORKS_TABLE_QUERY";

tablesWithOverriddenCompatibilityVersionSQL="SELECT
v.vm_name, v.$VMS_CLUSTER_COMPATIBILITY_VERSION_COLUMN
FROM vms v JOIN $CLUSTER_TABLE c ON c.$CLUSTER_PK_COLUMN=v.$VMS_CLUSTER_FK_COLUMN
WHERE v.$VMS_CLUSTER_COMPATIBILITY_VERSION_COLUMN <> c.compatibility_version"

if [ $(executeSQL "$tablesWithOverriddenCompatibilityVersionSQL" | wc -l) -gt 0 ]; then
  printSection "VMs with overridden cluster compatibility version"
  printTable "$tablesWithOverriddenCompatibilityVersionSQL"
fi

printSection " System Users"
printTable "SELECT
                $(projectionCountingRowsWithOrder surname, name),
                surname  AS \"Surname\",
                name  AS \"First Name\",
                username  AS \"User name\",
                email  AS \"E-mail\"
            FROM
                users
            ORDER BY surname, name"


cleanup_db
