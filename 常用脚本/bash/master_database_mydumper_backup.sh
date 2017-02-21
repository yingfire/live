#!/bin/bash
#------------------------------------

#------------------------------------

#导入root环境变量
mail_user_group="bm.it.svr@paidui.com"
this_script_dir="/u1/scripts/dbbak"
ignore_database_file="${this_script_dir}/db.txt"
remote_rsync_ip_and_mode="10.20.1.2::rom"
local_ip="10.20.10.3"
mysql_user="root"
mysql_pass="123456"
mysql_port="3306"
mysql_sock="/data/mysql/mysql_3306/mysql_3306.sock"
myslq_command="mysql -u ${mysql_user} -p${mysql_pass} -S ${mysql_sock} -NBe"
date_today=`date -I`
hostname=`hostname`

mysql_backup_path="/data/mydumper_bak"
mysql_backup_fie="${mysql_backup_path}/${date_today}"
mysql_backup_log_path="/var/log/dbbak"
mysql_backup_log_name="${mysql_backup_log_path}/mydumper_${date_today}.log"
rsync_backup_log_name="${mysql_backup_log_path}/rsync_${date_today}.log"

#检测服务器信息
check_mysql_backup_db_ip="*.*.*.*"
check_mysql_backup_db_user="replication"
check_mysql_backup_db_passwd="123456"
check_mysql_backup_db_name="backup_vpc_hd"
check_mysql_backup_db_table="mysql_backup_status"
check_mysql_backup_db_command="mysql -h ${check_mysql_backup_db_ip} -u ${check_mysql_backup_db_user} -p${check_mysql_backup_db_passwd} ${check_mysql_backup_db_name} -NBe"
check_mysql_backup_db_filed="server_name,server_ip,server_port,start_time,stop_time,total_number_of_database,backup_path,backup_size,backup_status,backup_remarks,remote_rsync_status,date"


#检测备份目录和日志目录
[ -d ${mysql_backup_fie} ] || mkdir -p ${mysql_backup_fie}
[ -d ${mysql_backup_log_path} ] || mkdir -p ${mysql_backup_log_path}

#
total_number_of_database=0

#数据库备份函数
database_backup () {
while read db
do
	if ! grep ${db} ${ignore_database_file};then
		total_number_of_database=$((total_number_of_database+1))
		/usr/local/bin/mydumper -u ${mysql_user} -p ${mysql_pass} -S ${mysql_sock} -B ${db} -c -o ${mysql_backup_path}/${date_today}/${db}
		if [ $? -eq 0 ];then
			echo "`date +'%F %T'` database ${db} dump successful"  >> ${mysql_backup_log_name}
		else
			echo "`date +'%F %T'` database ${db} dump failed" >> ${mysql_backup_log_name}
		fi
	fi
done< <(${myslq_command} "show databases")
}
#sql函数
insert_check_mysql_backup_db () {
${check_mysql_backup_db_command} "SET NAMES utf-8; INSERT INTO ${check_mysql_backup_db_table}(${check_mysql_backup_db_filed}) values(${check_mysql_backup_db_value})"
}
restart_mysql () {
/bin/bash  /u1/scripts/restart_mysql.sh
sleep 300
}
remote_rsync_database_backup () {
rsync -qulr --progress --partial ${mysql_backup_path}/ ${remote_rsync_ip_and_mode}/${local_ip}
if [ $? -eq 0 ];then
	echo "`date +'%F %T'` database  transport successful" >> ${rsync_backup_log_name}
else
	echo "`date +'%F %T'` database transport failed" >> ${rsync_backup_log_name}
fi
}
judge_status () {
mysql_backup_number=`grep failed ${mysql_backup_log_name}|wc -l`
rsync_backup_number=`grep failed ${rsync_backup_log_name}|wc -l`
mysql_backup_question=`grep 'No space' ${mysql_backup_log_name}|wc -l`
if [ ${mysql_backup_number} -eq 0 ];then
	mysql_backup_status="成功"
	if [ ${rsync_backup_number} -eq 0 ];then
		remote_rsync_status="成功"
	else
		remote_rsync_status="失败"
	fi
else
	mysql_backup_status="失败"
	if [ ${mysql_backup_question} -eq 0 ];then
		mysql_backup_remarks="其他"
	else
		mysql_backup_remarks="磁盘空间不足"
	fi
	remote_rsync_status="失败"
fi
check_mysql_backup_db_value="'${hostname}','${local_ip}','${mysql_port}','${db_backup_start_time}','${db_backup_stop_time}','${total_number_of_database}','${mysql_backup_path}','${mysql_backup_size}','${mysql_backup_status}','${mysql_backup_remarks}','${remote_rsync_status}','${date_today}'"
}
#打包数据库并删除未打包文件,清除14天前的备份
compress_delete_backup_file () {
cd ${mysql_backup_path}
nice -10 tar jcf ${date_today}.tar.bz2 ${date_today} > /dev/null 2>&1
mysql_backup_size=`du -sh ${date_today}.tar.bz2|awk '{print $1}'`
rm -rf ${mysql_backup_path:=UNSET}/${date_today}
find ${mysql_backup_path:=UNSET}/ -ctime +14 -exec rm -f {} \;
}

#流程
#备份前重启数据库释放内存
restart_mysql
#备份开始
echo > ${mysql_backup_log_name}
echo > ${rsync_backup_log_name}
echo "===================`date +'%F %T'` 备份开始===================" >> ${mysql_backup_log_name}
db_backup_start_time=`date +'%F %T'`
#备份数据库
database_backup
echo "===================`date +'%F %T'` 备份结束===================" >> ${mysql_backup_log_name}
db_backup_stop_time=`date +'%F %T'`
#打包数据库并删除未打包文件,清除14天前的备份
compress_delete_backup_file
#将本地备份上传到远程
remote_rsync_database_backup
#判断备份和rsync的状态
judge_status
#插入数据库
insert_check_mysql_backup_db
