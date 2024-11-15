#!/bin/bash
#name: step3.sh
#authro: xiangchen
#date: 2023-06-18
#version: v1.0

##################################
# The target of this script is that replace the j2 file
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
check_env_file "gvar_component_var_dir"
check_env_file "download_repo_dir"
check_env_file "gvar_component_deploy_path"
log "[INFO] check env file Success!"

# used parameters
env2json_filename="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/env.json"
env2kv_filename="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/env.kv"
need_sub_dir=$(echo {{gvar_component_var_dir}} | sed 's/[ ,;]\+/ /g')

# add env extend file
echo "env2json_filename=$env2json_filename"  >> $env_extend_file
echo "env2kv_filename=$env2kv_filename"  >> $env_extend_file
echo "need_sub_dir=\"$need_sub_dir\""  >> $env_extend_file


### Function ###
function customized_modules(){
    # cp file, use for first install
    if [ "${gvar_component_name}"x == "pulsar_zookeeper"x ]; then
        cp -f ${download_repo_dir}/conf_j2/myid.j2  ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/pulsar_env_zookeeper.sh.j2  ${download_repo_dir}/conf/pulsar_env.sh.j2
        cp -f ${download_repo_dir}/conf_j2/zookeeper.conf.j2 ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2 ${download_repo_dir}/conf/

        [ ! -e "${download_repo_dir}/conf/myid.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/myid.j2) error!"
        [ ! -e "${download_repo_dir}/conf/pulsar_env.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/pulsar_env.sh.j2) error!"
        [ ! -e "${download_repo_dir}/conf/zookeeper.conf.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/zookeeper.conf.j2) error!"
        [ ! -e "${download_repo_dir}/conf/pulsar_tools_env.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2) error!"
    elif [ "${gvar_component_name}"x == "pulsar_broker"x ]; then
        cp -f ${download_repo_dir}/conf_j2/pulsar_env_broker.sh.j2  ${download_repo_dir}/conf/pulsar_env.sh.j2
        cp -f ${download_repo_dir}/conf_j2/broker.conf.j2 ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2 ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/client.conf.j2 ${download_repo_dir}/conf/

        [ ! -e "${download_repo_dir}/conf/pulsar_env.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/pulsar_env.sh.j2) error!"
        [ ! -e "${download_repo_dir}/conf/broker.conf.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/broker.conf.j2) error!"
        [ ! -e "${download_repo_dir}/conf/pulsar_tools_env.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2) error!"
        [ ! -e "${download_repo_dir}/conf/client.conf.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/client.conf.j2) error!"
    elif [ "${gvar_component_name}"x == "pulsar_bookie"x ]; then
        cp -f ${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2 ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/bkenv.sh.j2  ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/bookkeeper.conf.j2 ${download_repo_dir}/conf/

        [ ! -e "${download_repo_dir}/conf/bkenv.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/bkenv.sh.j2) error!"
        [ ! -e "${download_repo_dir}/conf/bookkeeper.conf.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/bookkeeper.conf.j2) error!"
        [ ! -e "${download_repo_dir}/conf/pulsar_tools_env.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2) error!"
    elif [ "${gvar_component_name}"x == "pulsar_autorecover"x ]; then
        cp -f ${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2 ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/bkenv.sh.j2  ${download_repo_dir}/conf/
        cp -f ${download_repo_dir}/conf_j2/bookkeeper-autorecover.conf.j2 ${download_repo_dir}/conf/bookkeeper.conf.j2


        [ ! -e "${download_repo_dir}/conf/bkenv.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/bkenv.sh.j2) error!"
        [ ! -e "${download_repo_dir}/conf/bookkeeper.conf.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/bookkeeper.conf.j2) error!"
        [ ! -e "${download_repo_dir}/conf/pulsar_tools_env.sh.j2" ] && log "[ERROR] cp config file(${download_repo_dir}/conf_j2/pulsar_tools_env.sh.j2) error!"
    fi

}

function source_base_conf(){
    # rewrite,use for first install
    cmd_env2json="${download_repo_dir}/bin/env2json"
    cmd_jinja2_sub="${download_repo_dir}/bin/var_jinja2_sub"

    log "[INFO] cmd_env2json:${cmd_env2json}"
    log "[INFO] cmd_jinja2_sub:${cmd_jinja2_sub}"
    #cmd_add_hosts="${download_repo_dir}/bin/add_hosts_env"
    [ ! -x $cmd_env2json ]  &&  log "[ERROR: Need cmd file:$cmd_env2json, and has executable permissions ]" && exit 1
    [ ! -x $cmd_jinja2_sub ]  &&  log "[ERROR: Need cmd file:$cmd_jinja2_sub, and has executable permissions ]" && exit 1
    #[ ! -x $cmd_add_hosts ]  &&  log "[ERROR: Need cmd file:$cmd_add_hosts, and has executable permissions ]" && exit 1

}

# step 1
function generate_env_file(){
    # backup var
    cd $(dirname ${env2json_filename})
    ${cmd_env2json}
    [ $? -ne 0 ] && log "[ERROR]: exec1 env2json FAIL!" && exit 1
    ${cmd_env2json} -i ${env_file},${env_extend_file} -j ${env2json_filename} -k ${env2kv_filename}
    [ $? -ne 0 ] && log "[ERROR]: exec2 env2json FAIL!" && exit 1
}

# step 2
function subvar_process(){
    [ $# -ne 1 ] && log "[ERROR]: Need parameter basedir for ${need_sub_dir}" && exit 1
    cd $1
    log "[INFO] Need sub dir is : $need_sub_dir"
    local break_flag=0
    for i in $need_sub_dir;
    do
        [ ! -d $i ] && continue
        for line in $(find $i -name "*.j2" -type f);do
            local src_name=$(echo $line)
            local dst_name=$(echo $line | sed 's/.j2$//g')

            $cmd_jinja2_sub -j ${env2json_filename} -i $src_name -o $dst_name
            ret=$?
            [ $ret -ne 0 ] && log "[ERROR]: cmd exec FAIL. -> { $cmd_jinja2_sub -j $env2json_filename -i $src_name -o $dst_name  }" &&  exit 1
            done
    done
    [ $break_flag -eq 1 ] && log "[ERROR]: subvar_process error, exit" && exit 1
}

# step 3
function check_subvar_process(){
    for i in $need_sub_dir;
    do
        find $i -type f ! -name "*.j2" -exec grep -Iq . {} \; | while read line
        do
            ret=$(grep -E "\{\{.*\}\}" $line -c)
            [ $ret -ne 0 ] && echo "ERROR: $line var not sub, can usecmd: find $line -type f -exec grep -Iq . {} \; -and -print, grep -E "\{\{.*\}\}" $line -c " && exit 1
            [ $ret -eq 0 ] && exit 0
        done
    done
}


### Main ###
customized_modules
log "[INFO] customized_modules execution complete"

source_base_conf
log "[INFO] source_base_conf execution complete"

generate_env_file
log "[INFO]: Generate json env file and kv env file"

subvar_process ${download_repo_dir}
log "[INFO]: The j2 file is replaced"

check_subvar_process
log "[INFO]: Check that the replacement is complete"


