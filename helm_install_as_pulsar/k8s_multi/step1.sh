#!/bin/bash
# name: step1.sh
# authro: xiangchen
# update: 2023-06-18
# version: v1.0

##################################
# The target of this script is production env-file and extend env-file
###################################


### comm define ###
current_dir="$(cd $(dirname $0);pwd)"
user="$(whoami)"
script_pid=$$
env_file="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/env.txt"
env_extend_file="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/env_extend.txt"
function_base_file="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}/{{gvar_install_component_requestid}}/function_base.txt"

function log(){
    local prefix="[$(date +"%F %H:%M:%S")]:"
	echo "$prefix $@ "
}

### Base Function ### BEGIN
# check install dir
function Check_mkdir_dir(){
    local test_dir=$1
    [ "${test_dir}"x == ""x ] && echo "[ERR] Variable acquisition failure, ${test_dir}" && exit 1
    # mkdir dir
    if [ ! -d ${test_dir} ] ;then
        umask 0022
        sudo mkdir -p ${test_dir}
        ret=$?
        [ $ret -ne 0 ] && echo "[ERR] mkdir ${test_dir} fail" && exit 1
        sudo chmod -R a+x ${test_dir}
        sudo chmod 777 ${test_dir}
        #sudo chown {{ cluster_install_user }}:{{ cluster_install_user }} ${test_dir}
    fi

    # Check directory read and write permissions
    [ -e ${test_dir}/test_dir_rw.txt ] && rm ${test_dir}/test_dir_rw.txt
    [ -e ${test_dir}/test_dir_rw.txt ] && echo "[ERR] Failed to delete the temporary test" && exit 1

    # Verify directory read and write permissions
    touch ${test_dir}/test_dir_rw.txt ; ret=$?
    [ $? -eq 0 ] && rm ${test_dir}/test_dir_rw.txt
    [ $? -ne 0 ] && echo "[ERR] Description Failed to verify directory read and write permissions, dir is $test_dir" && exit 1
}

function Backup_env(){
    mkdir -p $(dirname  ${env_file})
    ret=$?;[ ${ret} -ne 0 ] && log "[ERROR] mkdir error: target file is  ${env_file})"  && exit 1
    env | grep -Eiv 'PROMPT_COMMAND=' | grep -Eiv '=file_default$' > ${env_file}
    set > $(dirname $env_file)/set.txt
    touch ${env_extend_file}
    touch ${function_base_file}
}


# action
Check_mkdir_dir $(dirname ${env_file})
Backup_env
log "[INFO] backup env done!"

# Check_install_base
# log "[INFO] check and source install base"

# check dir
#Check_mkdir_dir {{cluster_install_path}}
log "[INFO] check or mkdir {{cluster_install_path}} Success!"

component_deploy_path=$(dirname {{gvar_component_deploy_path}})
Check_mkdir_dir ${component_deploy_path}
log "[INFO] check or mkdir {{gvar_component_deploy_path}} Success!"

Check_mkdir_dir {{gvar_component_repo_path}}
log "[INFO] check or mkdir {{gvar_component_repo_path}} Success!"

Check_mkdir_dir {{gvar_component_repo_path}}/{{gvar_install_component_requestid}}
log "[INFO] check or mkdir {{gvar_component_repo_path}}/{{gvar_install_component_requestid}} Success!"

# logs_dir

logs_dir={{cluster_install_path}}/{{gvar_cluster_name}}/logs/{{gvar_component_name}}
Check_mkdir_dir $logs_dir
echo "logs_dir=$logs_dir" >> $env_extend_file
log "[INFO] check or mkdir $logs_dir Success!"

data_dir={{cluster_install_path}}/{{gvar_cluster_name}}/data/{{gvar_component_name}}
Check_mkdir_dir $data_dir
echo "data_dir=$data_dir" >> $env_extend_file
log "[INFO] check or mkdir $data_dir Success!"

secret_dir={{cluster_install_path}}/{{gvar_cluster_name}}/data/{{gvar_component_name}}/secret_token
Check_mkdir_dir $secret_dir
echo "secret_dir=$secret_dir" >> $env_extend_file
log "[INFO] check or mkdir $secret_dir Success!"

# generate base function
cat > $function_base_file << 'EOF'
function log(){
    local prefix="[$(date +"%F %H:%M:%S")]:"
	echo "$prefix $@ "
}

function check_env_file(){
    [ $# -ne 1 ] && log "[ERROR]  Need parameters for check" && exit 1
    # env file exist
    [ ! -e ${env_file} ] && log "[ERROR] envfile not exist. File path:${env_file}" && exit 1

    check_env=$1
    env_inFile_num=$( cat $env_file | grep -e "^${check_env}="  -c )

    env_inExtendFile_num=0
    [ -f $env_extend_file ] && env_inExtendFile_num=$( cat $env_extend_file | grep -e "^${check_env}="  -c )
    check_sum=$(( env_inFile_num + env_inExtendFile_num ))

    [ $check_sum -eq 0 ] && log "[ERROR]: get gvar "$check_env" fail, exit!" && exit 1
    [ $check_sum -gt 1 ] && log "[ERROR]: get gvar "$check_env" fail, in the env file hava multiple var. exit!" && exit 1

    # check env file
    if [ ${env_inFile_num} -eq 1 ];then
        env_file_value=$(cat $env_file | grep -e "^${check_env}=" | awk -F'=' '{print $2}')
        env_para_vulue=$(eval echo "$""${check_env}")

        [ ${env_file_value}x == ""x ] && log "[ERROR] Variable:$check_env in the file is null" && exit 1
        [ ${env_para_vulue}x == ""x ] && log "[ERROR] Variable:$check_env in enviroment is null" && exit 1
        [ ${env_file_value}x != ${env_para_vulue}x ] && log "[ERROR] Variable:$check_env in the file and environment variables are inconsistent.The env File is ${env_file_value}, The environment is ${env_para_vulue}" && exit 1
    fi

    # check env extend file
    if [ ${env_inExtendFile_num} -eq 1 ];then
        env_file_value=$(cat $env_extend_file | grep -e "^${check_env}=" | awk -F'=' '{print $2}')
        env_para_vulue=$(eval echo "$""${check_env}")

        [ ${env_file_value}x == ""x ] && log "[ERROR] Variable:$check_env in the file is null" && exit 1
        [ ${env_para_vulue}x == ""x ] && log "[ERROR] Variable:$check_env in enviroment is null" && exit 1
        #[ ${env_file_value}x != ${env_para_vulue}x ] && log "[ERROR] Variable:$check_env in the file and environment variables are inconsistent.The env File is ${env_file_value}, The environment is ${env_para_vulue}" && exit 1
    fi

    log "[INFO] check Variable:$check_env Success"
}

EOF

log "[INFO] done "

