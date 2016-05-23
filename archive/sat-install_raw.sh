
# Post script this to KS? Not sure we know everything at that stage though, like IF names....
#
# TODO
# Add gathering /asking of info such as IF names, disk names etc etc.

nmcli con add type team con-name team0 ifname team0 ip4 10.128.8.199/25 gw4 10.128.8.129  ipv4.dns 169.40.0.1 +ipv4.dns 169.40.0.2
nmcli con add type team-slave con-name team0-p0 ifname ens6f0 master team0
nmcli con add type team-slave con-name team0-p1 ifname ens3f0 master team0
nmcli c up team0-p0
nmcli c up team0-p1
nmcli c up team0

# Then subscription manager

subscription-manager config --server.proxy_hostname=pri-proxy.am.hedani.net
subscription-manager config --server.proxy_port=8080
subscription-manager register --auto-attach

# Set to 7Server...

subscription-manager release --set=7Server

# RH Says so!
yum update -y

# Before we do just about anything, configure NTP!

yum -y erase chrony
yum -y install ntp

cat > /etc/ntp.conf << EOF
server ntp1.am.hedani.net prefer
server ntp2.am.hedani.net prefer
server ntp3.am.hedani.net prefer

server ntp1.eu.hedani.net
server ntp2.eu.hedani.net
server ntp3.eu.hedani.net
server ntp1.ap.hedani.net
server ntp2.ap.hedani.net
server ntp3.ap.hedani.net

driftfile /var/ntp/ntp.drift
statsdir /var/ntp/ntpstats/
filegen peerstats file peerstats type week enable
restrict default noquery
restrict 127.0.0.1
EOF

systemctl restart ntpd.service


# Install maultipath and set it up

yum -y install device-mapper-multipath
mpathconf --enable --with_multipathd y --user_friendly_names n

# Then setup vols
#/var/lib/mongodb       250G    Dedicated Disks Y       The mongo database which supports the content related data which is stored in the pulp filesystem
#/var/lib/pgsql 120G    Shared Disks OK Y               This filesystem will grow in relation to the number of reports.
#/var/lib/pulp  800G    Dedicated Disks Y               The pulp filesystem contains the data (rpms and images)
#/var/lib/candlepin 16G Shared Disk OK  Y               The candlepiubscriptions.
#/var/lib/foreman       16G     Shared Disk OK  Y               Provisioning related data, caches and assets.
#/var/lib/puppet        16G     Shared Disk OK  Y               Puppet data for the puppet master
#/var/www/pulp          16G     Shared Disk OK  Y               Pulp content http / https entry points
#/var/lib/elasticsearch 16G     Shared Disk OK  Y               Elastic search index data
#/etc/puppet/environments       16G     Shared Disk OK  Y               Puppet environments
#/var/lib/tftpboot      16G     Shared Disk OK  Y               This location  PXE configuration files managed by Satellite.
#/var/lib/dhcpd*        16G     Shared Disk OK  Y               DHCP lease data.

# <APPLICATION>_<type>_LV
# <env>_<APPLICATION>_<type>_VG

# Where:

# env is one of P, D, T, U (Production, Development, Test, UAT)
# APPLICATION is uppercase and must contain ONE of the following:
# Freeform descriptor of the application utilizing this space (max 15 chars)
# database name
# SHARED to indicate this is shared between applications
# type is one of  data, logs, redo, archive, app that will indicate the type of data being stored
# Examples

# So. P_SATELLITE_mongo_VG, P_SATELLITE_pulp_VG, P_SATELLITE_shared_VG
# And. SATELLITE_mongo_LV, SATELLITE_pulp_LV, SATELLITE_shared_LV
# NB: Check shared_LV - might split as cluster might expect it split?
# Pvcreate on ALL disks!
pvcreate /dev/mapper/360060e8007db30000030db300000304f
pvcreate /dev/mapper/360060e8007db30000030db300000304e
pvcreate /dev/mapper/360060e8007db30000030db300000304d
# Add disks to vgcreate as req.
vgcreate P_SATELLITE_pulp_VG /dev/mapper/360060e8007db30000030db300000304f
vgcreate P_SATELLITE_mongodb_VG /dev/mapper/360060e8007db30000030db300000304e
vgcreate P_SATELLITE_shared_VG /dev/mapper/360060e8007db30000030db300000304d
# Now the LV's!

lvcreate -l 100%FREE -n SATELLITE_mongodb_LV P_SATELLITE_mongodb_VG
lvcreate -l 100%FREE -n SATELLITE_pulp_LV P_SATELLITE_pulp_VG
lvcreate -L 120G -n SATELLITE_pgsql_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_candlepin_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_foreman_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_puppet_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_elasticsearch_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_environments_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_tftpboot_LV P_SATELLITE_shared_VG
lvcreate -L 16G -n SATELLITE_dhcpd_LV P_SATELLITE_shared_VG

# Format as xfs

for n in SATELLITE_pgsql_LV SATELLITE_candlepin_LV SATELLITE_foreman_LV SATELLITE_puppet_LV SATELLITE_elasticsearch_LV SATELLITE_environments_LV SATELLITE_
tftpboot_LV SATELLITE_dhcpd_LV; do
        mkfs.xfs /dev/P_SATELLITE_shared_VG/$n
done

mkfs.xfs /dev/P_SATELLITE_pulp_VG/SATELLITE_pulp_LV
mkfs.xfs /dev/P_SATELLITE_mongodb_VG/SATELLITE_mongodb_LV

# Mount these up
for mp in /var/lib/mongodb /var/lib/pgsql /var/lib/pulp /var/lib/candlepin /var/lib/foreman /var/lib/puppet /var/www/pulp /var/lib/elasticsearch /etc/puppe
t/environments /var/lib/tftpboot /var/lib/dhcpd; do
        LV=SATELLITE_${mp##*/}_LV
        VG=$(lvs | grep $LV | awk '{print $2}')
        mkdir -p $mp
        mount /dev/$VG/$LV $mp
done


# Subscribe to Satellite and HA chansa
subscription manager repos --enable rhel-ha-for-rhel-7-server-eus-rpms
# It'll need a poolid no doubt!
subscription-manager blah

subscription manager repos disable *
" " enable <some>

# Install Sat
yum install katello

# Then the cluster?
# Make sure ssh etc open for cluster to work?
# Or in general? - Use std settings.

# Oh, always include CSB and make sure hostinfo is *configured* - ok, at least region!

mkdir -p /usr/local/host

# Settings need to come from *somewhere* or do they? Satellite only. Capsules will be Sat built?

cat > /usr/local/host/hostinfo << EOF
REGION: CH
STAGE: PROD
NETWORKZONE: STANDARD
EOF

# Centrify - make sure computer accounts are created!!
yum -y install CentrifyDC CentrifyDC-openssh CentrifyDA

# Now do an adjoin...
adjoin -s gbl.etit.hedani.net

yum -y install CS_ntplogger # ??????? - name?
yum -y install CS_Core_CSB perl-Data-Dumper

# Install components, patrol, tripwire etc etc.

#groupadd -g 34001 patrol
#groupadd -g 34003 patusr
#groupadd -g 34004 patadm
#useradd -u 34001 -n patrol -g patrol -c "BMC Performance Manager, Service Account" -d /home/patrol -m -p 69w0O9H4I.46o -s /bin/noshell > /dev/null 2>&1
#chown patrol:patrol /home/patrol
#chmod 775 /home/patrol
#useradd -u 34003 -n patusr -g patusr -c "BMC Performance Manager, Connection Account" -d /home/patusr -m -p WYI3zCwQHKnkk -s /bin/bash > /dev/null 2>&1
#useradd -u 34004 -n patadm -g patadm -G patrol -c "BMC Performance Manager, Connection Account" -d /home/patadm -m -p tj1oMRojz.0hM -s /bin/bash> /dev/nul
l 2>&1

subscription-manager repos --enable rhel-7-server-optional-rpms
yum -y install compat-libstdc++-33 # Optional channel in RHEL7!
# We will need to get this from *somewhere!*
yum -y install CS_BML_PatrolAgent # DOESN'T WORK!!

# Configure.
cat > /opt/bmc/Patrol3/1.cfg << EOF
PATROL_CONFIG
"/AgentSetup/rtServers" = { REPLACE = "tcp:169.36.178.244:49113"},
"/AgentSetup/loadOnlyPreloadedKMs" = { REPLACE = "yes" },
"/AgentSetup/preloadedKMs" = { REPLACE = "AS_EVENTSPRING.km,AS_AVAILABILITY.km,AS_EVENTSPRING_ALL_COMPUTERS.km,CS.kml,PATROLAGENT.km,CPU.km,MEMORY.km,LOG.k
ml,MS_HARDWARE_SENTRY1.kml,CS_CAPMAN.kml,STORAGE.km,UNIX_OS.km,COLLECTORS.km,DCM.km,FILESYSTEM.km,PROCESS.km,PROCPRES.km,PROCCONT.km,SMP.km,SWAP.km,NBU_LOA
D.kml,CLONE.km,CLONE_CONT.km" },
"/AgentSetup/accessControlList" = { REPLACE = "*/*/*" }
EOF
. /opt/bmc/Patrol3/patrolrc.sh
pconfig -seclevel 2 +tcp 1.cfg
pconfig +RESTART -seclevel 2 +tcp

yum -y install VRTSpbx CS_NetBackup_Client_RHEL

yum -y install CS_TWagent
yum -y install CS_SPLAGT_code

# Now configure splunk?

