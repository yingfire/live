#/bin/bash
#用途:当count_fin_wait2数量大于70时,重启haproxy
#作者:刘邦正
#日期:2017-02-09
alert_time=`date '+%F %T'`
count_fin_wait2=`netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}' | grep FIN_WAIT2|awk '{print $2}'`
haproxy_url="/usr/local/haproxy/sbin/haproxy -f /usr/local/haproxy/etc/haproxy.cfg"
count_haproxy_process=`ps aux|grep "${haproxy_url}"|grep -v grep|wc -l`
kill_haproxy_index=0
start_haproxy_index=0

kill_haproxy (){
        killall haproxy
        sleep 1
}
start_haproxy (){
        /usr/local/haproxy/sbin/haproxy -f /usr/local/haproxy/etc/haproxy.cfg
        sleep 1
}
#判断FIN_WAIT2数量
	while [ ${count_fin_wait2:=0} -gt 70 ]
	do
		#判断haproxy进程是否存在
		while [ ${kill_haproxy_index} -le 3 ]
		do
			count_haproxy_process=`ps aux|grep "${haproxy_url}"|grep -v grep|wc -l`
			if [ ${count_haproxy_process} -ne 0 ];then
				kill_haproxy
				let kill_haproxy_index++
				echo "${alert_time}kill_haproxy number is ${kill_haproxy_index}" >> /tmp/ha_ok.log
				continue
			else
				echo "${alert_time} Haproxy was shutdown " >> /tmp/ha_ok.log
				kill_haproxy_index=4
				break
			fi
		done
		while [ ${start_haproxy_index} -le 3 ]
		do
			count_haproxy_process=`ps aux|grep "${haproxy_url}"|grep -v grep|wc -l`
			if [ ${count_haproxy_process} -eq 0 ];then
				start_haproxy
				let start_haproxy_index++
				echo "${alert_time}start_haproxy number is ${start_haproxy_index}" >> /tmp/ha_ok.log
				continue 
			else
				echo "${alert_time} Haproxy was start " >> /tmp/ha_ok.log
				start_haproxy_index=4
				break
			fi
		done
		exit
	done
#稳定后可以删除下面一行
echo "${alert_time} the count_fin_wait2 number is ${count_fin_wait2}" >> /tmp/ha_ok.log
