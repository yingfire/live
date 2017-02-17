#!/bin/bash

wget http://sourceforge.net/projects/msmtp/files/msmtp/1.4.31/msmtp-1.4.31.tar.bz2

tar -jxvf msmtp-1.4.31.tar.bz2 && cd msmtp-1.4.31

./configure --prefix=/usr/local/msmtp && make && make install

ln -s /usr/local/msmtp/bin/msmtp /usr/bin/msmtp

mkdir /usr/local/msmtp/etc 

cat >>/usr/local/msmtp/etc/msmtprc << ENDF
account default
host mail.paidui.com
port 25
from auto.bg@paidui.com
auth login
#tls no
#tls_certcheck off
user auto.bg
password public25BG
logfile /var/log/msmtp_bg.log
ENDF

yum install -y mutt

cat >> /root/.muttrc << ENDF
set sendmail="/usr/bin/msmtp -C /usr/local/msmtp/etc/msmtprc "
set use_from=no
#set realname="阿里云报告"
set from=auto.bg@paidui.com
set envelope_from=yes
set content_type="text/plain\;charset=utf-8"
set charset="utf-8
ENDF


echo "123.57.0.85 mail.paidui.com" >> /etc/hosts
