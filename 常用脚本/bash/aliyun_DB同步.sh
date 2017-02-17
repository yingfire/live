#!/bin/bash
#----------------------------------------------------------------------------------
#用途：阿里云增加DB集群
#作者：刘邦正
#时间：2016.06
#版本：1.0
#----------------------------------------------------------------------------------
DISK="/dev/vdb"
MYSQL_DATA="/data"
MYSQL_DIR="/data/mysql/mysql_3306"
ADD_DB_LOG="/usr/local/src/add_DB_cluster.log"
#远程登录执行用户
User="liubz"
Passwd="liubz"
Post="2222"
#外网IP
O_IP=`ifconfig eth1|awk -F '[ :]+' 'NR==2 {print $4}'`
#内网IP
I_IP=`ifconfig eth0|awk -F '[ :]+' 'NR==2 {print $4}'`

#安装依赖环境,将交互式转变为非交互式
count=`rpm -qa|grep expect|wc -l`
[ ${count} -eq 1 ] || yum -y install expect

#初始化DB
Initialize_DB () {
[ -d ${MYSQL_DIR} ] || mkdir -p ${MYSQL_DIR} 
SCRIPTS="/usr/local/mysql"
cd ${SCRIPTS} 
[ -x mysql_install_db ] && ./mysql_install_db --datadir=${MYSQL_DIR} || {
   chmod +x scripts/mysql_install_db
   scripts/mysql_install_db --datadir=${MYSQL_DIR}
  }
  chown -R mysql:mysql /data/mysql
  #修改配置文件(如何修改)
  #启动mysql
	/bin/start_mysql 1
}

#检测Mysql是否启动
Check_Mysql () {
PID_FILE="/data/mysql/mysql_3306/mysql_3306.pid"
START_MYSQL=`/bin/start_mysql 1`
#判断mysql的pid文件是否存在
if [ -e ${PID_FILE} ];then
  echo "Mysql Start OK" > ${ADD_DB_LOG}
else
  echo "Mysql Start Faild" >> ${ADD_DB_LOG}
  exit -1
fi
}

#添加mysql权限
##各IDC均添加如下权限
AllIdc_competence () {
mysql --socket=/data/mysql/mysql_3306/mysql_3306.sock -e "set password=password('123456');\
grant replication slave,replication client on *.* to 'replication'@'10.%.%.%' identified by 'pdw@evt@2012';\
grant all privileges  on *.* to 'pdwdbuser'@'10.%.%.%' identified by 'pdw@evt@2015' with grant option;\
grant all privileges  on *.* to 'pdwdbuser'@'%' identified by 'pdw@evt@2015';\
grant alter routine,create routine,event,execute,process,select  on *.* to 'romdbread'@'10.%.%.%' identified by 'pdw@rom@2015';"
}

##北京IDC添加权限
BeiJingIdc_competence () {
mysql -uroot -p123456 --socket=/data/mysql/mysql_3306/mysql_3306.sock -e "grant select on test.* to 'pdwdbuser'@'10.251.211.119' identified by 'pdw@evt@2015';\
grant select,show view  on *.* to 'dbread'@'10.170.233.151' identified by 'pdw@evt';\
flush privileges;"
}

##深圳IDC添加权限
ShenZhenIdc_competence () {
mysql -uroot -p123456 --socket=/data/mysql/mysql_3306/mysql_3306.sock -e "grant select on test.* to 'pdwdbuser'@'123.57.189.167' identified by 'pdw@evt@2015';\
grant select,show view  on *.* to 'dbread'@'123.56.158.42' identified by 'pdw@evt';\
flush privileges;"
}

#获取mysql-master bin.file&position,在从数据库如何获取
Master_sql () {
read -p "Please enter your Master_IP（内网IP）: " Master_IP
#mysql -uroot -p123456 --socket=/data/mysql/mysql_3306/mysql_3306.sock -e "show master status\G"
BinFile=`mysql -ureplication -ppdw@evt@2012 -h ${Master_IP} -e "show master status\G"|awk 'NR==2{print $2}'`
Position=`mysql -ureplication -ppdw@evt@2012 -h ${Master_IP} -e "show master status\G"|awk 'NR==3{print $2}'`
}
 
 #设置主从同步(从库)
Slave_sql () {
#read -p "Please enter your Master_IP: " Master_IP
#Check_IP $Master_IP
mysql -uroot -p123456 --socket=/data/mysql/mysql_3306/mysql_3306.sock -e "stop slave;\
change master to master_host='${Master_IP}',\
master_user='replication',\
master_password='pdw@evt@2012',\
master_log_file='${BinFile}',\
master_log_pos=${Position};\
start slave;"
}

#检测mysql主从状态
Master_slave_Check () {
#声明slave是一个数组
declare -a slave_is
slave_is=($(mysql -uroot -p123456 --socket=/data/mysql/mysql_3306/mysql_3306.sock -e "show slave status\G"|grep Running|awk '{print $2}'))
if [ "${slave_is[0]}"="yes" -a "${slave_is[1]}"="yes" ];then
  echo "Slave is running OK" >> ${ADD_DB_LOG}
else
  echo "Slave is Error" >> ${ADD_DB_LOG}
fi
}

#添加/etc/hosts(位于redis)
Xa_beijing_IP1="101.201.220.85"
Xa_beijing_IP2="101.200.3.32"
#setfacl -m u:liubz:rw /etc/hosts，提前给用户修改权限,并添加脚本已添加
Add_host_beijing () {
Add_host_file="/usr/local/src/add_hosts.sh"
read -p "Enter you domain name number: " num
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_beijing_IP1} "${Add_host_file}\ ${I_IP}\ ${num}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_beijing_IP2} "${Add_host_file}\ ${I_IP}\ ${num}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}
#深圳xa代理hosts设置
Xa_shenzhen_IP1="120.76.65.11"
Xa_shenzhen_IP2="120.76.40.219"
#setfacl -m u:liubz:rw /etc/hosts，提前给用户修改权限,并添加脚本已添加
Add_host_shenzhen () {
Add_host_file="/usr/local/src/add_hosts.sh"
read -p "Enter you domain name number: " num
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_shenzhen_IP1} "${Add_host_file}\ ${O_IP}\ ${num}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_shenzhen_IP2} "${Add_host_file}\ ${O_IP}\ ${num}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}

#重启mysql-proxy
#重启北京mysql-proxy
Restart_beijing_xa () {
#vim /etc/sudoers
#liubz  ALL=NOPASSWD:   /bin/kill			(提前给执行用户sudu权限)
Restart_Xa="/usr/local/src/restart_x_a.sh"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_beijing_IP1} "${Restart_Xa}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_beijing_IP2} "${Restart_Xa}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}
#重启深圳mysql-proxy
Restart_shenzhen_xa () {
#vim /etc/sudoers
#liubz  ALL=NOPASSWD:   /bin/kill			(提前给执行用户sudu权限)
Restart_Xa="/usr/local/src/restart_x_a.sh"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Xa_shenzhen_IP2} "${Restart_Xa}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}

#添加crontab
Crontab_Add () {
CRON_FILE="/var/spool/cron/root"
#echo -e "#xtrabackup 每周1 01:00全量备份\n0 1 * * 1  /bin/bash  /u1/scripts/dbbak/dbbak_xtrabackup.sh" >> ${CRON_FILE}
#echo -e "#xtrabackup 每周2-周7 01:00增量备份\n0 1 * * 2-7 /bin/bash /u1/scripts/dbbak/dbbak_xtrabackup_incre.sh" >> ${CRON_FILE}
echo -e "#MYSQL慢日志每日轮转\n0 8 * * * /bin/bash /u1/scripts/mysql_slowquery_log/mysql_slowquery_log.sh >&/dev/null" >> ${CRON_FILE}
#echo -e "#每天4:00重启mysqlproxy\n#0 4 * * * /bin/bash  /u1/scripts/restart_proxy.sh" >> ${CRON_FILE}
#echo -e "#6月4号因服务器硬件升级设定自动启动\n1 7 4 6 * /usr/bin/reboot" >> ${CRON_FILE}
echo -e "#每天7:00重启mysql\n0 7 * * * /bin/bash  /u1/scripts/restart_mysql.sh" >> ${CRON_FILE}
#echo -e "#MYSQL慢日志每日轮转\n0 8 * * * /bin/bash /u1/scripts/mysql_slowquery_log/mysql_slowquery_log.sh >&/dev/null" >> ${CRON_FILE}
echo -e "#每天凌晨4点备份一次数据库\n0 4 * * *  /bin/bash   /u1/scripts/dbbak/mydumper.sh" >> ${CRON_FILE}
}

#更改备份shell脚本IP
#Scripts_DIR
DBbak_Scripts_DIR="/u1/scripts/dbbak/"
Change_Back_ShellIP () {
cd ${DBbak_Scripts_DIR}
SHELL_A_IP=`grep ^IP dbbak_xtrabackup.sh |awk -F '[="]+' '{print $2}'`
SHELL_I_IP=`grep ^IP dbbak_xtrabackup_incre.sh |awk -F '[="]+' '{print $2}'`
sed -i "s/${SHELL_A_IP}/${I_IP}/g" dbbak_xtrabackup.sh
sed -i "s/${SHELL_I_IP}/${I_IP}/g" dbbak_xtrabackup_incre.sh
}

#更改慢日志检测脚本中本机IP
Mysql_Slowlog_Dir="/u1/scripts/mysql_slowquery_log"
Change_Slowlog_ShellIP () {
cd ${Mysql_Slowlog_Dir}
#sed -i "s/集群5/集群${num}/g" mysql_slowquery_log.sh
grep ROM mysql_slowquery_log.sh|awk -F "_" '{print $6}'|awk -F "(" 'NR==2{print $1}'|while read a;do
sed -i "s/${a}/北京ROM智慧云集群${num}从DB慢日志报告/g" mysql_slowquery_log.sh
done
grep ROM mysql_slowquery_log.sh|awk -F "_" 'NR==2 {print $7}' |while read b;do
sed -i "s/${b}/${O_IP}/g" mysql_slowquery_log.sh 
done
}

#添加监控
#setfacl -m u:liubz:rwx /usr/local/nagios/etc/servers,需要提前给执行用户权限
Add_Monitor () {
Add_Monitor_file="/usr/local/src/add_monitor.sh"
Monitor_IP="182.92.221.191"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Monitor_IP} "${Add_Monitor_file}\ ${O_IP}\ ${num}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}

#修改DB集群所在备份存放服务器的smb与nfs读写权限
Backup_beijing_IP="123.57.6.109"
Backup_shenzhen_IP="112.74.75.8"
#setfacl -m u:liubz:rw /etc/samba/smb.conf
#setfacl -m u:liubz:rw /etc/exports
#setfacl -m u:liubz:rw /etc/rsyncd.conf
DB_bak_beijing () {
Add_back_file="/usr/local/src/add_back.sh"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Backup_beijing_IP} "${Add_back_file}\ ${I_IP}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}

DB_bak_shenzhen () {
Add_back_file="/usr/local/src/add_back.sh"
expect -c "
	spawn ssh  -p ${Post} ${User}@${Backup_shenzhen_IP} "${Add_back_file}\ ${I_IP}"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password*\" {send \"${Passwd}\r\";exp_continue}
	\"*none*\" {exp_continue}
}"
}

#----------------------------------------------------------------------------脚本正式执行---------------------------------------------------------------------------------------------------------------

#初始化数据库，并启动mysql
Initialize_DB
#检测数据库是否启动
Check_Mysql
#所有IDC添加相应权限
AllIdc_competence
#选择北京或者深圳IDC，并添加相应权限
while true
do
	read -p "Enter the number,beijing is 1,shenzhen is 2: " city
	case  ${city} in
	1 )
	BeiJingIdc_competence
	while true 
		do
			read -p "If server is master ,please enter the number 1,slave is 2: " statu
			case ${statu} in
			1 )
			echo "The server is Master" >> ${ADD_DB_LOG}
			#修改beijing_xa代理设置
			Add_host_beijing
			[ $? -eq 0 ] && echo "add hosts beijing success" >> ${ADD_DB_LOG} || echo "add hosts beijing failure" >> ${ADD_DB_LOG}
			#重启mysql-proxy
			#Restart_beijing_xa
			break 
			;;
			2 )
			#获取mysql-master状态
			Master_sql
			#设置主从同步
			Slave_sql
			sleep 10
			#检测mysql主从状态
			Master_slave_Check
			break
			;;
			* )
			echo "USE:{1 or 2}"
			esac
		done
	break
	;;
	2 )
	ShenZhenIdc_competence
	while true 
		do
			read -p "If server is master ,please enter the number 1,slave is 2: " statu
			case ${statu} in
			1 )
			echo "The server is Master" >> ${ADD_DB_LOG}
			#修改xa代理设置(需要修改)
			Add_host_shenzhen
			[ $? -eq 0 ] && echo "Add hosts beijing success" >> ${ADD_DB_LOG} || echo "Add hosts beijing failure" >> ${ADD_DB_LOG}
			#重启mysql-proxy
			#Restart_shenzhen_xa
			break 
			;;
			2 )
			#获取mysql-master状态
			Master_sql
			#设置主从同步
			Slave_sql
			sleep 10
			#检测mysql主从状态
			Master_slave_Check
			break
			;;
			* )
			echo "USE:{1 or 2}"
			esac
		done
	break
	;;
	* )
	echo "USE:{1 or 2}"
	esac
done
#Add_Monitor
#Change_Back_ShellIP
#Change_Slowlog_ShellIP
#Crontab_Add
[ $? -eq 0 ] && echo "Add crontab successfull" >> ${ADD_DB_LOG} || echo "Add crontab failed" >> ${ADD_DB_LOG}





