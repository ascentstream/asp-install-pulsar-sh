#!/bin/bash
#name: step4.sh
#authro: xiangchen
#date: 2023-06-18
#version: v1.0

##################################
# The target of this script is that changing linked files
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

# check env file
check_env_file "gvar_component_name"
check_env_file "gvar_install_component_requestid"
check_env_file "gvar_component_repo_path"
check_env_file "gvar_component_deploy_path"
check_env_file "download_repo_dir"
log "[INFO] check env file Success!"

# used parameters
app_service_current="{{gvar_component_deploy_path}}"

# add env extend file
echo "app_service_current=$app_service_current"  >> $env_extend_file


### Function ###
function shutdown_old_service(){
    [ $# -ne 1 ] && log "[ERROR] Need stop bash script" && exit 1
    if [ -d ${app_service_current} ];then
        log "[INFO] exist old version service!"
        if [ "$1"x != "N"x ];then
            cd ${app_service_current}/bin
            sh $1
        else
            log "[INFO] No stop script is required"
        fi

        # unlink
        which unlink
        ret=$?
        if [ $ret -eq 0 ];then
            unlink ${app_service_current}
            ret_unlink=$?
            [ $ret_unlink -ne 0 ] && log "[ERROR] unlink old version service link" && exit 1
        else
            rm ${app_service_current}
            ret_rm=$?
            [ $ret_rm -ne 0 ] && log "[ERROR] rm old version service link" && exit 1
        fi
    else
        log "[INFO] Not exist old version service"
    fi

}
# If you want to stop, you need to put it in bin dir。If not, use "N".


function linked_new_version(){
    ln -s ${download_repo_dir} ${app_service_current}
    ret=$?
    [ $ret -ne 0 ] && log "[ERROR] linked new version error" && exit 1
}


### Main ###
# If you want to stop, you need to put it in bin dir。If not, use "N".
shutdown_old_service "N"

log "[INFO] stop service done"

linked_new_version
log "[INFO] linked new version success"

