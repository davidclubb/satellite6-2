#!/bin/bash
#
# Description:
#   - kickstart post-install script for kickstart Satellite 6 in HA mode
# Author:
#   - Dustin Scott, Red Hat
# Testing Environment(s):
#   - Platform: VMware
#   - OS: RHEL 7.1
#   - Satellite: 6.1
# Revision History:
#   - 05/03/2016 - Initital creation date
# Requirements:
#   - A/PTR DNS entries for all Satellite server nodes must be in place
#   - All packages listed in %packages% section must have installed correctly
#   - Red Hat Satellite subscriptions must be available for each Satellite in the cluster
#   - ONLY 2 active ethernet links (for bonding if NET_BOND is set to true)
#   - SSH connectivity via password
#

############################################################################
# CREATE FUNCTIONS                                                         #
############################################################################

# create log function for our custom logging
# $1 = messge to log
# $2 = log level (optional)
f_log() {
  # log everything as info unless we want it to be different (second argument)
  if [[ ${2} ]]; then LEVEL=${2}; else LEVEL="info"; fi
  echo "[${LEVEL}] [$(date +%F)] [$(date +%k:%M:%S)] ${1}" >> ${LOG_FILE}

  # also log the message to console if LOG_CONSOLE is true
  # NOTE: typically STDOUT is logged to /root/ if we need it
  if [[ ${LOG_CONSOLE} == "true" ]]; then echo ${1}; fi
}

# runs a command and checks the return value for those commands that require simple validation
# $1 = command to run
# $2 = valid exit code (optional - assumes 0 if no input)
# TODO: possible custom exit codes as input
f_run_cmd() {
  # set the valid exit code
  if [[ ${2} ]]; then VALID_EXIT_CODE="${2}"; else VALID_EXIT_CODE="0"; fi

  # run the command and check the return value
  f_log "${FUNCNAME[0]}: Running Command: ${1}"
  eval ${1}
  RETVAL=$?
  if [[ ${RETVAL} != ${VALID_EXIT_CODE} ]]; then
    f_log "${FUNCNAME[0]}: Failed command: ${1}"
    f_log "${FUNCNAME[0]}: Invalid exit code: ${RETVAL} (Valid code is ${VALID_EXIT_CODE})"
    exit 1
  else
    return 0
  fi
}

# function for backing things up
# $1 = thing to backup (directory or file)
# $2 = command instead of copy (e.g. mv - optional)
f_bak() {
  # set a suffix
  BAK_SUFFIX="bak"

  # log what we are backing up
  f_log "${FUNCNAME[0]}: Backing up ${1}"

  # we don't need any fancy backup for kickstart (simply append BAK_SUFFIX)
  if [[ -f ${1} ]]; then
    if [[ ${2} ]]; then CMD=${2}; else CMD='cp -u'; fi
    f_run_cmd "${CMD} ${1} ${1}.${BAK_SUFFIX}"
  elif [[ -d ${1} ]]; then
    if [[ ${2} ]]; then CMD=${2}; else CMD='cp -r'; fi
    f_run_cmd "${CMD} ${1} ${1}.${BAK_SUFFIX}"
  fi
}

# configure the hostname on the node
# $1 = the new hostname to set
f_cfg_hostname() {
  f_log "${FUNCNAME[0]}: changing hostname from $(hostname) to ${1}"
  if [[ ${RH_MAJOR_VER} == '7' ]]; then
    f_bak ${NET_HN_FILE}
    f_run_cmd "hostnamectl set-hostname ${1}"
  else
    f_bak ${NET_HN_FILE}
    f_run_cmd "hostname ${1}"
    f_run_cmd "sed -i '/HOSTNAME=/d' ${NET_HN_FILE}"
    f_run_cmd "echo 'HOSTNAME=${1}' ${NET_HN_FILE}"
  fi
}

# configure the ip on the node
# NOTE: assumes all other networking is the same (just changes the ip)
# $1 = new ip address
# $2 = interface to configure
f_cfg_ip() {
  f_log "${FUNCNAME[0]}: changing ip address to ${1} on interface ${2}"
  NET_INT_FILE="${NET_FILE_PFX}${2}"
  f_bak ${NET_INT_FILE}
  cat > ${NET_INT_FILE} << EOF
  TYPE=Ethernet
  BOOTPROTO=static
  DEVICE=${2}
  ONBOOT=yes
  NM_CONTROLLED=no
  PEERDNS=no
  IPADDR=${1}
  PREFIX=${NET_PREFIX}
  GATEWAY=${NET_GW}
EOF

}

# configure a service based on the release
# $1 = service name
# $2 = action (e.g. start/stop)
f_cfg_svc() {
  f_log "${FUNCNAME[0]}: Performing action ${2} on service ${1}"
  if [[ ${RH_MAJOR_VER} == '6' ]]; then
    f_run_cmd "service ${1} ${2}"
  else
    f_run_cmd "systemctl ${2} ${1}"
  fi
}

# sets the host file as per red hat reference architecture cluster recommendations
# $1 = list of FQDNs of all at nodes
f_set_hosts_file() {
  # backup the file first
  f_bak ${NET_HOSTS_FILE}

  # configure the hosts file
  f_log "${FUNCNAME[0]}: Updating ${NET_HOSTS_FILE} file"
  echo -e "\n# satellite cluster config\n" >> ${NET_HOSTS_FILE}

  # NOTE: pass in the FQDN for this to work
  for FQDN in "$@"; do
    f_log "${FUNCNAME[0]}: Adding entry for ${FQDN} to ${NET_HOSTS_FILE}"
    SHORT_NAME="$(echo ${FQDN} | awk -F'.' '{print $1}')"
    IP_ADDR="$(getent ahosts $(FQDN) | tail -1 | awk '{print $1}')"
    echo -e "${IP_ADDR}\t${FQDN}\t${SHORT_NAME}" >> ${NET_HOSTS_FILE}
  done
  return 0
}

############################################################################
# SET VARIABLES                                                            #
# TODO: possibly move these to a separate config file that can be sourced  #
############################################################################

#################################
# general variables             #
#################################
RH_MAJOR_VER=$(rpm -qa --queryformat '%{VERSION}\n' '(redhat|sl|slf|centos|oraclelinux)-release(|-server|-workstation|-client|-computenode)' | cut -c1)

#################################
# log variables                 #
#################################
LOG_FILE="/root/sat6_ks.log.$(date +%F_%k%M%S)"
LOG_CONSOLE="true"
LOG_DEBUG="true"

#################################
# network variables             #
#################################

# network file variables
NET_HOSTS_FILE="/etc/hosts"
NET_DIR="/etc/sysconfig/network-scripts"
NET_FILE_PFX="${NET_DIR}/ifcfg-"
if [[ ${RH_MAJOR_VER} == '7' ]]; then
  NET_HN_FILE="/etc/hostname"
else
  NET_HN_FILE="/etc/sysconfig/network"
fi

# netweork interface retlated variables
NET_BOND="true"
NET_BOND_NAME="team0"
NET_BOND_IF1_NAME="team0-p0"
NET_BOND_IF2_NAME="team0-p1"
NET_ACTIVE_LINKS=""
NET_IP_LINK=""
for INT in $(ls /sys/class/net | grep -v '^lo' | head -2); do
  if [[ $(ethtool ${INT} | grep -i 'link detected' | awk '{print $NF}') == yes ]]; then
    NET_ACTIVE_LINKS+=" ${INT}"
  fi

  if [[ -n $(ip addr show ${INT} | grep 'inet [1-9]') ]]; then
    NET_IP_LINK="${INT}"
  fi
done

# network ip related variables
NET_GW="$(netstat -rn | grep '^0.0.0.0' | awk '{print $2}')"
NET_DNS="$(grep -i '^nameserver' /etc/resolv.conf | awk '{print $2}')"
NET_IP_MASK="$(ip addr show ${NET_IP_LINK} | grep 'inet [1-9]' | awk '{print $2}')"
NET_CURRENT_IP="$(echo ${NET_IP_MASK} | awk -F'/' '{print $1}')"
NET_PREFIX="$(echo ${NET_IP_MASK} | awk -F'/' '{print $2}')"

# network proxy variables
NET_PROXY="pri-proxy.am.hedani.net"
NET_PROXY_PORT="8080"

# network ntp variables
NET_NTP_PREFER="        ntp1.am.hedani.net \
                        ntp2.am.hedani.net \
                        ntp3.am.hedani.net"
NET_NTP_ALT="           ntp1.eu.hedani.net \
                        ntp2.eu.hedani.net \
                        ntp3.eu.hedani.net \
                        ntp4.eu.hedani.net \
                        ntp5.eu.hedani.net \
                        ntp6.eu.hedani.net"
NET_NTP_CONF="/etc/ntp.conf" # just in case we want chrony
NET_NTP_SVC="ntpd" # just in case we want chrony
NET_NTP_CONF_OPTS=(     "driftfile /var/ntp/ntp.drift" \
                        "statsdir /var/ntp/ntpstats/" \
                        "filegen peerstats file peerstats type week enable" \
                        "restrict default noquery" \
                        "restrict 127.0.0.1")

#################################
# satellite variables           #
#################################

# satellite node configuration
# NOTE: add more nodes as needed
NODE_HA_FQDN="rhsatksha.cs.net"
NODE_HA_IP=$(if [[ ${NODE_HA_FQDN} ]]; then getent ahosts $(NODE_HA_FQDN) | tail -1 | awk '{print $1}'; fi)
NODE1_FQDN="rhsatks-01.cs.net"
NODE1_IP=$(if [[ ${NODE1_FQDN} ]]; then getent ahosts $(NODE1_FQDN) | tail -1 | awk '{print $1}'; fi)
NODE2_FQDN="rhsatks-02.cs.net"
NODE2_IP=$(if [[ ${NODE2_FQDN} ]]; then getent ahosts $(NODE2_FQDN) | tail -1 | awk '{print $1}'; fi)
NODE3_FQDN=""
NODE3_IP="$(if [[ ${NODE3_FQDN} ]]; then dig ${NODE3_FQDN} +short | tail -1; fi)"
NODES="${NODE1_FQDN} ${NODE2_FQDN} ${NODE3_FQDN}"
NODES_ALL="${NODE_HA_FQDN} ${NODES}"

# satellite service configuration
SAT6_VER="6.1"
SAT6_USER="admin"
SAT6_PASS="changeme"
SAT6_ORG="Credit Suisse"
SAT6_LOCATION="AM"
SAT6_ENABLE_TFTP="true"
SAT6_ENABLE_DHCP="false"
SAT6_ENABLE_DNS="false"
if [[ ${SAT6_VER} == '6.2' ]]; then
  SAT6_PKG='satellite'
  SAT6_INSTALL_CMD='foreman-installer --scenario katello'

  # create base option set
  SAT6_INSTALL_OPTS="   --foreman-admin-username '${SAT6_USER}' \
                        --foreman-admin-password '${SAT6_PASS}' \
                        --foreman-initial-location '${SAT6_LOCATION}' \
                        --foreman-initial-organization '${SAT6_ORG}'"

  # add options for tftp if it is requested
  if [[ ${SAT6_ENABLE_TFTP} == "true" ]]; then
    SAT6_INSTALL_OPTS+="--capsule-tftp true \
                        --capsule-tftp-servername $(hostname)"
  fi

  # add options for dhcp if it is requested
  if [[ ${SAT6_ENABLE_DHCP} == "true" ]]; then
    SAT6_INSTALL_OPTS+="--capsule-dhcp-true \
                        --capsule-dhcp-interface ${SAT6_DHCP_INTERFACE} \
                        --capsule-dhcp-range \"${SAT6_DHCP_START} ${SAT6_DHCP_END}\" \
                        --capsule-dhcp-gateway ${SAT6_DHCP_GATEWAY} \
                        --capsule-dhcp-nameservers ${SAT6_DHCP_NAMESERVERS}"
  fi

  # add options for dns if it is requested
  if [[ ${SAT6_ENABLE_DNS} == "true" ]]; then
    SAT6_INSTALL_OPTS+="--capusle-dns-true \
                        --capsule-dns-interface ${SAT6_DNS_INTERFACE} \
                        --capsule-dns-zone ${SAT6_DNS_ZONE} \
                        --capsule-dns-forwarders ${SAT6_DNS_FORWARDER} \
                        --capsule-dns-reverse ${SAT6_DNS_REVZONE}"
  fi
else
  SAT6_PKG='katello'
  SAT6_INSTALL_CMD='katello-installer'

  # create base option set
  SAT6_INSTALL_OPTS="   --foreman-admin-username '${SAT6_USER}' \
                       --foreman-admin-password '${SAT6_PASS}' \
                        --foreman-initial-location '${SAT6_LOCATION}' \
                        --foreman-initial-organization '${SAT6_ORG}'"

  # add options for tftp if it is requested
  if [[ ${SAT6_ENABLE_TFTP} == "true" ]]; then
    SAT6_INSTALL_OPTS+="--capsule-tftp true \
                        --capsule-tftp-servername $(hostname)"
  fi

  # add options for dhcp if it is requested
  if [[ ${SAT6_ENABLE_DHCP} == "true" ]]; then
    SAT6_INSTALL_OPTS+="--capsule-dhcp-true \
                        --capsule-dhcp-interface ${SAT6_DHCP_INTERFACE} \
                        --capsule-dhcp-range \"${SAT6_DHCP_START} ${SAT6_DHCP_END}\" \
                        --capsule-dhcp-gateway ${SAT6_DHCP_GATEWAY} \
                        --capsule-dhcp-nameservers ${SAT6_DHCP_NAMESERVERS}"
  fi

  # add options for dns if it is requested
  if [[ ${SAT6_ENABLE_DNS} == "true" ]]; then
    SAT6_INSTALL_OPTS+="--capusle-dns-true \
                        --capsule-dns-interface ${SAT6_DNS_INTERFACE} \
                        --capsule-dns-zone ${SAT6_DNS_ZONE} \
                        --capsule-dns-forwarders ${SAT6_DNS_FORWARDER} \
                        --capsule-dns-reverse ${SAT6_DNS_REVZONE}"
  fi
fi

# foreman specific variables
FOREMAN_CONFIG_FILE='/etc/foreman/settings.yml'

# subscription-manager variables (RHN)
SM_USER='dustin.scott@rhn-cs'
SM_PASS='R3dhat1!'
SM_SAT6_REPOS="         rhel-7-server-rpms \
                        rhel-7-server-satellite-${SAT6_VER}-rpms \
                        rhel-server-rhscl-7-rpms \
                        rhel-ha-for-rhel-7-server-rpms"

# ssh key variables
SSH_KEY_TYPE='rsa'
SSH_KEY_FILE='/root/.ssh/id_rsa'
SSH_KEY_BITS='4096'

# firewall configuration variables
# NOTE: set these as PROTOCOL:PORT and let firewall configuration in main program loop handle this
FW_PORTS="80:tcp 443:tcp 5647:tcp 8140:tcp 2224:tcp 3121:tcp 5404:udp 5405:udp 21064:tcp"
if [[ ${SAT6_ENABLE_TFTP} == "true" ]]; then FW_PORTS="${FW_PORTS} 69:udp"; fi
if [[ ${SAT6_ENABLE_DHCP} == "true" ]]; then FW_PORTS="${FW_PORTS} 67:udp 68:udp"; fi
if [[ ${SAT6_ENABLE_DNS} == "true" ]]; then FW_PORTS="${FW_PORTS} 53:udp 53:tcp"; fi

#################################
# storage configuration         #
#################################
# TODO: possible associative array
# TODO: ask user for inputs
STORAGE_SHARED_VG_NAME="p_satellite_shared_vg"
STORAGE_SHARED_VG_DEVICE="/dev/sde"
STORAGE_PULP_VG_NAME="pulp_vg"
STORAGE_PULP_VG_DEVICE="/dev/sdc"
STORAGE_MONGODB_VG_NAME="mongo_vg"
STORAGE_MONGODB_VG_DEVICE="/dev/sdb"
STORAGE_PGSQL_VG_NAME="pgsql_vg"
STORAGE_PGSQL_VG_DEVICE="/dev/sdd"
VGS="${SAT_VG_NAME} ${PULP_VG_NAME} ${MONGODB_VG_NAME} ${PGSQL_VG_NAME}"
PVS="${SAT_VG_DEVICE} ${PULP_VG_DEVICE} ${MONGODB_VG_DEVICE} ${PGSQL_VG_DEVICE}"
if [[ ${RH_MAJOR_VER} == '7' ]]; then
  STORAGE_FS_TYPE='xfs'
else
  STORAGE_FS_TYPE='ext4'
fi

# create associate arrays for volumes with following properties
# [service]_vg_name = volume group name the volume belongs to
# [service]_lv_name = logical volume name of the volume
# [service]_lv_size_cmd = lvcreate command to run to size the lvm
# [service]_lv_mount_dir = where to mount the volume
# [service]_lv_fs_type = file system type (e.g. XFS or EXT4)
# [service]_lv_device = device where file system is mounted
declare -A STORAGE_VOLS

# pulp storage properties
STORAGE_VOLS=(          [pulp_vg_name]="${STORAGE_PULP_VG_NAME}" \
                        [pulp_lv_name]="pulp_lv" \
                        [pulp_lv_size_vg_pct]="100" \
                        [pulp_lv_mount_dir]="/var/lib/pulp" \
                        [pulp_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [pulp_lv_device]="/dev/mapper/${STORAGE_PULP_VG_NAME}-${STORAGE_VOLS[pulp_lv_name]}")

# foreman storage properties
STORAGE_VOLS+=(         [foreman_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [foreman_lv_name]="foreman_lv" \
                        [foreman_lv_size_vg_pct]="10" \
                        [foreman_lv_mount_dir]="/var/lib/foreman" \
                        [foreman_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [foreman_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[foreman_lv_name]}")

# puppet storage properties
STORAGE_VOLS+=(         [puppet_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [puppet_lv_name]="puppet_lv" \
                        [puppet_lv_size_vg_pct]="10" \
                        [puppet_lv_mount_dir]="/var/lib/foreman" \
                        [puppet_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [puppet_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[puppet_lv_name]}")

# wwwpulp storage properties
STORAGE_VOLS+=(         [wwwpulp_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [wwwpulp_lv_name]="wwwpulp_lv" \
                        [wwwpulp_lv_size_vg_pct]="10" \
                        [wwwpulp_lv_mount_dir]="/var/www/pulp" \
                        [wwwpulp_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [wwwpulp_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[wwwpulp_lv_name]}")

# elasticsearch storage properties
STORAGE_VOLS+=(         [elastic_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [elastic_lv_name]="elastic_lv" \
                        [elastic_lv_size_vg_pct]="10" \
                        [elastic_lv_mount_dir]="/var/lib/elasticsearch" \
                        [elastic_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [elastic_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[elastic_lv_name]}")

# candlepin storage properties
STORAGE_VOLS+=(         [candlepin_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [candlepin_lv_name]="candlepin_lv" \
                        [candlepin_lv_size_vg_pct]="10" \
                        [candlepin_lv_mount_dir]="/var/lib/candlepin" \
                        [candlepin_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [candlepin_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[candlepin_lv_name]}")

# mongodb storage properties
STORAGE_VOLS+=(         [mongodb_vg_name]="${STORAGE_MONGODB_VG_NAME}" \
                        [mongodb_lv_name]="mongodb_lv" \
                        [mongodb_lv_size_vg_pct]="100" \
                        [mongodb_lv_mount_dir]="/var/lib/mongodb" \
                        [mongodb_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [mongodb_lv_device]="/dev/mapper/${STORAGE_MONGODB_VG_NAME}-${STORAGE_VOLS[mongodb_lv_name]}")

# pgsql storage properties
STORAGE_VOLS+=(         [pgsql_vg_name]="${STORAGE_PGSQL_VG_NAME}" \
                        [pgsql_lv_name]="pgsql_lv" \
                        [pgsql_lv_size_vg_pct]="100" \
                        [pgsql_lv_mount_dir]="/var/lib/pgsql" \
                        [pgsql_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [pgsql_lv_device]="/dev/mapper/${STORAGE_PGSQL_VG_NAME}-${STORAGE_VOLS[pgsql_lv_name]}")

# puppetenv properties
STORAGE_VOLS+=(         [puppetenv_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [puppetenv_lv_name]="puppetenv_lv" \
                        [puppetenv_lv_size_vg_pct]="10" \
                        [puppetenv_lv_mount_dir]="/etc/puppet/environments" \
                        [puppetenv_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [puppetenv_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[puppetenv_lv_name]}")

# tftp properties
# NOTE: no need to update if SAT_ENABLE_TFTP is not true
STORAGE_VOLS+=(         [tftp_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [tftp_lv_name]="tftpboot_lv" \
                        [tftp_lv_size_vg_pct]="10" \
                        [tftp_lv_mount_dir]="/var/lib/tftpboot" \
                        [tftp_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [tftp_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[tftp_lv_name]}")

# dns properties
# NOTE: no need to update if SAT_ENABLE_DNS is not true
STORAGE_VOLS+=(         [dns_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [dns_lv_name]="named_lv" \
                        [dns_lv_size_vg_pct]="10" \
                        [dns_lv_mount_dir]="/var/lib/named" \
                        [dns_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [dns_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[dns_lv_name]}")

# dhcp properties
# NOTE: no need to update if SAT_ENABLE_DHCP is not true
STORAGE_VOLS+=(         [dhcp_vg_name]="${STORAGE_SHARED_VG_NAME}" \
                        [dhcp_lv_name]="dhcp_lv" \
                        [dhcp_lv_size_vg_pct]="10" \
                        [dhcp_lv_mount_dir]="/var/lib/dhcp" \
                        [dhcp_lv_fs_type]="${STORAGE_FS_TYPE}" \
                        [dhcp_lv_device]="/dev/mapper/${STORAGE_SHARED_VG_NAME}-${STORAGE_VOLS[dhcp_lv_name]}")

# create a list of the relevant storages to use
STORAGE_LIST="pulp foreman puppet wwwpulp elastic candlepin mongodb pgsql puppetenv"
for SVC in DNS DHCP TFTP; do
  VARNAME="SAT6_ENABLE_${SVC}"
  if [[ "${!VARNAME}" == "true" ]]; then
    STORAGE_LIST+="$(echo " ${SVC}" | tr '[:upper:]' '[:lower:]')"
  fi
done

#################################
# cluster configuration         #
#################################
CLUSTER_USER="hacluster"
CLUSTER_PASS="redhat"

############################################################################
# MAIN PROGRAM LOOP                                                        #
# TODO: for now this is generic.  we can do fancy things later             #
############################################################################

#################################
# create log                    #
#################################
if [ ! -f ${LOG_FILE} ]; then touch ${LOG_FILE}; fi

#################################
# os setup: configure network   #
#################################
f_log "os setup: configuring networking"

# configure the system hostname and ip address as the ha satellite address
f_log "configure network: setting hostname to ha name"
f_cfg_hostname ${NODE_HA_FQDN}
f_log "configure network: setting ip address to satellite ha node ip on active interface"
f_cfg_ip ${NODE_HA_IP} ${NET_IP_LINK}

# restart network and wait a bit for it to come up
f_cfg_svc network restart
sleep 10

#################################
# os setup: update hosts        #
# TODO: remove function         #
#################################
f_log "os setup: configuring hosts file"
f_set_hosts_file ${NODES_ALL}

#################################
# os setup: update ntp.conf     #
#################################
f_log "os setup: configuring ntp"
f_bak ${NET_NTP_CONF} 'mv -f'
for PREF_SRV in ${NET_NTP_PREFER}; do
  f_log "os setup: adding preferred ntp server ${PREF_SRV} to ${NET_NTP_CONF}"
  echo "server ${PREF_SRV} prefer" >> ${NET_NTP_CONF}
done
for ALT_SRV in ${NET_NTP_ALT}; do
  f_log "os setup: adding alternate ntp server ${ALT_SRV} to ${NET_NTP_CONF}"
  echo "server ${ALT_SRV}" >> ${NET_NTP_CONF}
done
for OPT in "${NET_NTP_CONF_OPTS[@]}"; do
  f_log "os setup: adding ntp option ${OPT} to ${NET_NTP_CONF}"
  echo "${OPT}" >> ${NET_NTP_CONF}
done
for ACTION in {start,enable}; do f_cfg_svc "ntpd" "${ACTION}"; done

#################################
# subscription-manager setup    #
#################################
if [[ ${NET_PROXY} ]]; then f_run_cmd "subscription-manager config --server.proxy_hostname=${NET_PROXY}"; fi
if [[ ${NET_PROXY_PORT} ]]; then f_run_cmd "subscription-manager config --server.proxy_port=${NET_PROXY_PORT}"; fi
f_run_cmd "subscription-manager register --username=${SM_USER} --password=${SM_PASS}"
f_run_cmd "subscription-manager attach --pool=$(subscription-manager list --available --matches='Red Hat Satellite' --pool-only --no-overlap | head -1)"
f_run_cmd "subscription-manager release --set=${RH_MAJOR_VER}Server"
f_run_cmd "subscription-manager repos --disable=\"*\""
for REPO in ${SM_SAT6_REPOS}; do
  f_log "subscription-manager setup: Enabling repository ${REPO}"
  f_run_cmd "subscription-manager repos --enable=\"${REPO}\""
done

#################################
# os setup: configure multipath #
#################################
f_log "os setup: configuring multipathing"
f_run_cmd "mpathconf --enable --with_multipathd y --user_friendly_names n"

#################################
# os setup: install pacemaker   #
#################################
f_log "os setup: installing pacemaker"
f_run_cmd "yum install -y fence-agents resource-agents pcs ccs pacemaker"
for ACTION in {start,enable}; do f_cfg_svc pcsd ${ACTION}; done

#################################
# ssh key setup                 #
# TODO: insert copy keys logic  #
#################################
f_log "ssh key setup: generating and copying ssh keys to available nodes"
f_run_cmd "ssh-keygen -t ${SSH_KEY_TYPE} -b ${SSH_KEY_BITS} -f ${SSH_KEY_FILE} -N ''"

#################################
# firewall setup                #
#################################
f_log "firewall setup: creating firewall rules"
for RULE in ${FW_PORTS}; do
  PORT=$(echo ${RULE} | cut -d':' -f1)
  PROTOCOL=$(echo ${RULE} | cut -d':' -f2)
  f_log "firewall setup: Adding rule with port ${PORT} and protocol ${PROTOCOL}"
  if [[ ${RH_MAJOR_VER} == '7' ]]; then
    f_run_cmd "firewall-cmd --permanent --add-port=${PORT}/${PROTOCOL}"
    f_run_cmd "firewall-cmd --reload > /dev/null"
  else
    f_run_cmd "iptables -A INPUT -p ${PROTOCOL} --dport ${PORT} -j ACCEPT"
    f_run_cmd "iptables-save"
    f_cfg_svc iptables restart
  fi
done

#################################
# named setup                   #
# TODO: create dns/dhcp/tftp    #
# TODO: integrate f_bak         #
#################################
if [[ ${SAT6_ENABLE_DNS} == 'true' ]]; then
  f_log "named setup: dns is enabled. configuring named before setting storage."
  if [[ -e ${NAMED_DIR} ]]; then
    f_log "moving ${NAMED_DIR} before creating storage"
    f_cfg_service named stop
    f_run_cmd "mv ${NAMED_DIR} ${NAMED_DIR}.bak"
  fi
else
  f_log "named setup: dns is not enabled.  skipping named setup."
fi

#################################
# storage setup: create vgs     #
# TODO: loop (if possible)      #
#################################
f_log "storage setup: creating volume groups: ${VGS}"
f_run_cmd "pvcreate ${PVS}"
f_run_cmd "vgcreate ${SAT_VG_NAME} ${SAT_VG_DEVICE}"
f_run_cmd "vgcreate ${PULP_VG_NAME} ${PULP_VG_DEVICE}"
f_run_cmd "vgcreate ${MONGODB_VG_NAME} ${MONGODB_VG_DEVICE}"
f_run_cmd "vgcreate ${PGSQL_VG_NAME} ${PGSQL_VG_DEVICE}"

#################################
# storage setup: create lvms    #
#                create fs      #
#                create dirs    #
#                mount fs       #
#################################

# perform storage creation on our relevant storages (determined via STORAGE_LIST)
for SVC in "${STORAGE_LIST}"; do
  # create the lvm
  f_log "storage setup: create lvm for ${SVC}"
  f_run_cmd "lvcreate -l +${STORAGE_VOLS[$SVC_lv_size_vg_pct]}%FREE -n ${STORAGE_VOLS[$SVC_lv_name]} ${STORAGE_VOLS[$SVC_vg_name]}"

  # create the file system
  f_log "storage setup: create file system for ${SVC}"
  f_run_cmd "mkfs.${STORAGE_VOLS[$SVC_lv_fs_type]} ${STORAGE_VOLS[$SVC_lv_device]}"

  # create the directories
  f_log "storage setup: create file system directory (mount point) for ${SVC}"
  f_run_cmd "mkdir -p ${STORAGE_VOLS[$SVC_lv_mount_dir]}"

  # mount the file system
  f_log "storage setup: mounting file system for ${SVC}"
  f_run_cmd "mount ${STORAGE_VOLS[$SVC_lv_device]} ${STORAGE_VOLS[$SVC_lv_mount_dir]}"
done

#################################
# update server                 #
#################################
f_log "update server: updating server before installing satellite"
f_run_cmd "yum update -y"

#################################
# install satellite             #
#################################
f_log "install satellite: installing satellite package ${SAT6_PKG}"
f_run_cmd "yum install ${SAT6_PKG} -y"

#################################
# config satellite              #
#################################
f_log "configure satellite: configuring satellite"
f_run_cmd "${SAT6_INSTALL_CMD} ${SAT6_INSTALL_OPTS}"
for FQDN in $NODES_ALL; do
  if [[ -z $(grep "  - ${FQDN}" ${FOREMAN_CONFIG_FILE}) ]]; then
    f_run_cmd "sed -i '/:trusted_hosts:/a \ \ - ${FQDN}' ${FOREMAN_CONFIG_FILE}"
  fi
done

#################################
# config cluster                #
#################################
f_log "configure cluster: setting password for ${CLUSTER_USER}"
f_run_cmd "usermod --password $(echo ${CLUSTER_PASS} | openssl passwd -1 -stdin) ${CLUSTER_USER}"

#################################
# os setup: final network config#
# TODO: config bonding          #
#################################

# configure bonding if requested
if [[ ${NET_BOND} == "true" ]]; then
  f_log "configure network: configuring bonding"

  # set the interface which we will be configuring
  CFG_INT="${NET_BOND_NAME}"
else
  CFG_INT="${NET_IP_LINK}"
fi
