#!/bin/bash
##################################install########
cd /usr/local/src/
wget http://pilotfiber.dl.sourceforge.net/project/denyhosts/denyhosts/2.6/DenyHosts-2.6.tar.gz
tar zxf DenyHosts-2.6.tar.gz
cd DenyHosts-2.6
#yum install python -y
python setup.py install >> /dev/null
###############################init.d#############
cd /usr/share/denyhosts/
cp daemon-control-dist daemon-control
chown root:root daemon-control
chmod 700 daemon-control
ln -s /usr/share/denyhosts/daemon-control /etc/init.d/denyhosts
chkconfig --add denyhosts
chkconfig denyhosts on
###########################config################
cp denyhosts.cfg-dist denyhosts.cfg
sed -i s/PURGE_DENY\ =/PURGE_DENY\ =\ 3d/ denyhosts.cfg
sed -i s/DENY_THRESHOLD_ROOT\ =\ 1/DENY_THRESHOLD_ROOT\ =\ 5/ denyhosts.cfg
sed -i s/AGE_RESET_ROOT=25d/AGE_RESET_ROOT=3d/ denyhosts.cfg
/etc/init.d/denyhosts  start  
