#!/bin/bash
#-----------------------------------------------------------------------
. /root/.bash_profile
/usr/local/mysql/bin/mysqladmin shutdown -uroot -p'123456' -S /data/mysql/mysql_3306/mysql_3306.sock
/bin/start_mysql 1
