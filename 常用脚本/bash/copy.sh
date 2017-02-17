#!/bin/bash
#用途:	1.解压拷贝web文件到指定位置，并更改版本号
#	2.解压服务文件到指定位置
#原理：	1.分别获取版本号,存储在列表中
#	2.将列表生成字典,方便取用
#作者:	刘邦正
#时间:	2017.2.14
#版本:	v2
Source_dir="/data/source"
Web_dir="/data/clusters/release"
Api_dir="/data/clusters/service_release"
Bn_version=`ls -l ${Source_dir}|tail -n +2|grep bn|awk '{print $9}'`
#wx 和执行权限会重合,这里使用_wx过滤
Wx_version=`ls -l ${Source_dir}|tail -n +2|grep _wx|awk '{print $9}'`
Rom_version=`ls -l ${Source_dir}|tail -n +2|grep rom|awk '{print $9}'`
Api_version=`ls -l ${Source_dir}|tail -n +2|grep service|awk '{print $9}'`
#---------------------------------------获取web版本号并存储到数组当中--------------------------------------
Get_version () {
#声明Version_list是一个列表
declare -a Version_list
#列表去重(备份时有用,此处没有多大用,只是生成了一个数组)
for Version_name in ${1}
do
	 #判断元素是否在数组中
	if echo "${Version_list[@]}" | grep "${Version_name:1:3}" &>/dev/null;then
		continue
	else
	#将元素追加到数组中
		Version_list=(${Version_list[@]} ${Version_name:1:3});
	fi
done
echo ${Version_list[@]}
}
#-----------------------------------解压文件到指定目录&拷贝文件&修改配置文件-----------------------------------------------
unzip_package () {
for version_number in ${Version_dict[${key}]}
do
	cd ${Source_dir}
	package_name="v${version_number}_${key}"
	unzip  -qo ${package_name}.zip -d ${package_name}
	#区分copy时的路径
	if [ ${key} == "service" ];then
	        file_path="${Api_dir}/PDW.SCM.API_v${version_number}"
	elif [ ${key} == "rom" ];then
	        file_path="${Web_dir}/v${version_number}"
	else
		file_path="${Web_dir}/v${version_number}/${key}"
	fi
	\cp -r ${package_name}/* ${file_path}
	#修改webconfig
	if [ ${key} != "service" ];then 
		#过滤出老的版本号
		old_web_version=`grep key=\"Version\" ${file_path}/Web.config |awk -F '"' '{print $4}'`
		#过滤出需要更改的版本号
		change_web_version=`grep key=\"Version\" ${file_path}/Web.config |awk -F '"' '{print $4}'|awk -F '.' '{print $3}'`
		change_web_version=$((change_web_version+1))
		new_web_version=${version_number}.${change_web_version}
		#修改版本号
		sed -i "s/key=\"Version\" value=\"${old_web_version}\"/key=\"Version\" value=\"${new_web_version}\"/g"  ${file_path}/Web.config
		echo "${key}"
		echo "${old_web_version} ==> ${new_web_version}"
	fi
done
}
#获取需要发布内容的版本号
Api_version_list=`Get_version "${Api_version}"`
Rom_version_list=`Get_version "${Rom_version}"`
Wx_version_list=`Get_version "${Wx_version}"`
Bn_version_list=`Get_version "${Bn_version}"`
#声明Version_dict是一个字典
declare -A Version_dict
Version_dict=(
[service]="${Api_version_list}"
[rom]="${Rom_version_list}"
[wx]="${Wx_version_list}"
[bn]="${Bn_version_list}"
)
#-----------------------------------------主体逻辑------------------------------------------
for key in $(echo ${!Version_dict[*]})
do
	#去除value为空的key
	if [ -n "${Version_dict[${key}]}" ];then
		if [ ${key} == "service" ];then
			unzip_package
		elif [ ${key} == "rom" ];then
			unzip_package
		elif [ ${key} == "wx" ];then
			unzip_package
		elif [ ${key} == "bn" ];then
			unzip_package	
		else
			continue
		fi
	fi
done
