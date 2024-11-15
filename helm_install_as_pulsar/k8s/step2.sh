#!/bin/bash
#name: step2.sh
#authro: xiangchen
#date: 2023-06-18
#version: v1.0

##################################
# The target of this script is that download the target compressed file
###################################

# comm define
current_dir="$(cd $(dirname $0);pwd)"
user="$(whoami)"
script_pid=$$
env_file="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/env.txt"
env_extend_file="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/env_extend.txt"
function_base_file="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/function_base.txt"
# source env extend file
[ ! -f $env_extend_file ] && log "[ERROR] The extend file was not found!" && exit 1
[ ! -f $function_base_file ] && log "[ERROR] The function_base file was not found!" && exit 1
[ -f $env_extend_file ] && source $env_extend_file
[ -f $function_base_file ] && source $function_base_file

# check use var
check_env_file "gvar_component_name"
check_env_file "gvar_cluster_name"
check_env_file "gvar_install_component_requestid"
check_env_file "gvar_component_repo_path"
check_env_file "gvar_install_component_package"
log "[INFO] check env file Success!"

# used parameters
download_repo_dir="{{gvar_component_repo_path}}/{{gvar_install_component_requestid}}"
download_repo_file="{{gvar_component_repo_path}}/{{gvar_install_component_requestid}}/$(basename {{gvar_install_component_package}})"

# add env extend file
echo "download_repo_dir=${download_repo_dir}" >> $env_extend_file
echo "download_repo_file=${download_repo_file}" >> $env_extend_file


### Function ###
function download_package_http(){
    # check file exist
    local md5_status_file="$(dirname ${env_file})/curl_status.txt"
    curl -I ${gvar_install_component_package} 2> /dev/null 1> ${md5_status_file}
    log "[INFO] curl status file done. File name : ${md5_status_file}"


    # check md5
    package_exist=$(cat ${md5_status_file}| grep 'HTTP/1.1 200 OK' -c)
    [ ${package_exist} -eq 0 ] && log "[ERROR]: file<${gvar_install_component_package}> not exist!" && exit 1

    package_md5=$(cat ${md5_status_file} | grep 'Content-MD5' | awk '{print $2}' | grep -Po '[0-9a-zA-Z]*')
    log "[INFO] package_stats is HTTP 200 , package_md5 is $package_md5"

    # cp from local dir
    if [ "${package_md5}"x != ""x ];then
       local local_md5_status_file="$(dirname ${env_file})/local_file_md5.txt"
       find ${gvar_component_repo_path} -maxdepth 3 -name "$(basename ${gvar_install_component_package})" -exec  md5sum {} \; > ${local_md5_status_file}

       is_match=$(cat ${local_md5_status_file} | grep -c ${package_md5} )
       if [ ${is_match} -gt 0 ] ;then
           log "[INFO] The package is not modify ,so use local repo package "
           match_file=$(cat ${local_md5_status_file} | grep ${package_md5} | head -n 1 | awk '{print $2}' )
           log "[INFO] match_file is $match_file"
           cp ${match_file} {{gvar_component_repo_path}}/{{gvar_install_component_requestid}}
           ret=$?
           [ $ret -eq 0 ] && log "[INFO]: cp package from ${match_file}" && return
       fi
    fi

    # download
    log "[INFO]: download package from ${gvar_install_component_package} "
    rm -f ${download_repo_dir}/*.tar*
    curl ${gvar_install_component_package} -o ${download_repo_file} 2> /dev/null

    # check md5
    download_md5sum=$(md5sum ${download_repo_file} | awk '{print $1}')

    log "download_md5sum:${download_md5sum}, package_md5:${package_md5}"
    [ "${download_md5sum}"x == "${package_md5}"x ] && echo "[INFO]: download file success"
    [ "${download_md5sum}"x != "${package_md5}"x ] && echo "[ERROR] download file fail,exit" && exit 1

}

function unzip_tar_file(){
    check_download_repo_dir_filenum=$( ls ${download_repo_dir}| wc -l )
    [ ${check_download_repo_dir_filenum} -ne 1 ] && log "[ERROR] There are multiple files in the repo directory, It should be one" && exit 1
    tar -xzf ${download_repo_file} -C ${download_repo_dir}
    ret=$?
    [ $ret -ne 0 ] && log "[ERROR]: extracting file is fail,cmd: tar -xzf ${download_repo_file} -C ${download_repo_dir}"
    cd ${download_repo_dir}/;chmod -R a+x *
}

### Main ###
log "[INFO] component type is ${gvar_component_package_type}"
case ${gvar_component_package_type} in
   "http")
      download_package_http
    ;;
    *)
      log "[ERR]: Unsupported package model "
      exit 1
    ;;
esac

log "[INFO] Start extracting files..."
unzip_tar_file
log "[INFO] Extracting files Success"
