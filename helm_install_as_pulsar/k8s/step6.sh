#!/bin/bash
#name: step6.sh
#authro: xiangchen
#date: 2023-06-18
#version: v1.0

##################################
# The target of this script is that clean dir
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
check_env_file "cluster_install_path"
check_env_file "app_service_current"
check_env_file "logs_dir"
check_env_file "data_dir"
check_env_file "cluster_operator_namespace"
check_env_file "cluster_install_namespace"
check_env_file "gvar_k8s_config_name"
check_env_file "gvar_k8s_config_context"
check_env_file "kubectl_file"
check_env_file "helm_file"
check_env_file "kubectl_config"
check_env_file "kubectl_context"
#check_env_file "kubectl_bin"
#check_env_file "helm_bin"
check_env_file "po_release_name"
check_env_file "fm_release_name"
check_env_file "cm_release_name"
check_env_file "asp_release_name"

log "[INFO] check env file Success!"

# used parameters
tmp_dir="/tmp/as_pulsar_install_info/{{gvar_cluster_name}}/{{gvar_component_name}}"

# add env extend file
echo "tmp_dir=$tmp_dir" >> $env_extend_file

### Function ###
function check_single_component_status(){
    [ $# -ne 2 ] && log "[ERROR]: Need parameter asp_release_name in \$1, component in \$2" && exit 1
    local test_ret=0
    test_num=$($kubectl_bin get pod -n ${1} | grep -E "asp-${2}" -c)
    if [ $test_num -eq 0 ];then
        test_ret=1
    else
        tmpfile=$(mktemp)
        $kubectl_bin get pod -n ${1} | grep -E "asp-${2}" | awk '{print $3}' > $tmpfile
        while read line ;do
            [ "$line"x != 'Running'x ] && test_ret=1 && break
        done < $tmpfile
    fi
    [ $test_ret -eq 0 ] && return 0
    [ $test_ret -ne 0 ] && return 1
}

function check_all_component_status(){
    [ $# -ne 2 ] && log "[ERROR]: Need parameter namespace in \$1, need_check_component list in \$2" && exit 1
    success_num=0
    unsuccess_num=0
    success_list=()
    unsuccess_list=()
    check_component=$2
    for i in ${check_component[@]};do
        check_single_component_status $1 $i ; ret=$?
        if [ $ret -eq 0 ];then
            success_num=$((success_num+1))
            success_list[success_num]="$i"
        else
            unsuccess_num=$((unsuccess_num+1))
            unsuccess_list[unsuccess_num]="$i"
        fi
    done
}

# need_check_component=("zookeeper" "bookie" "broker" "pulsar-detector" "toolset" "recovery"  "grafana" "prometheus" "proxy" "streamnative-console")
function check_install_status(){
    [ $# -ne 1 ] && log "[ERROR]: Need parameter namespace in \$1" && exit 1
    need_check_component=("zookeeper" "bookie" "broker" "pulsar-detector" "toolset" "recovery"  "grafana" "prometheus" "proxy")
    need_check_component_num=$(echo ${need_check_component[@]} | awk -F' ' '{print NF}')

    for i in {1..30};do
        # the Last try
        if [ $i -eq 30 ];then
            echo "=====RESULT======"
            log "[ERROR]The installation is NOT complete in 10 min, please go to the k8s management console to check;If you need to redeploy, you can resubmit it through the console."
            echo "[BASE INFO]:"
            echo "namespace $cluster_install_namespace"
            echo "In_Progress("${unsuccess_list[*]}")"
            $kubectl_bin get pod -n $cluster_install_namespace
            exit 0
        fi

        #
        check_all_component_status $1 "${need_check_component[*]}"
        success_list_num=$(echo ${success_list[@]} | awk -F' ' '{print NF}')
        unsuccess_list_num=$(echo ${unsuccess_list[@]} | awk -F' ' '{print NF}')
        if [ $need_check_component_num -eq $success_list_num ];then
           echo "=====RESULT======"
           log "[INFO] check install SUCCESS, components:${success_list_num[*]}"
           log "[DEBUG] SUCC_component("${success_list[*]}")"
           # todo
           exit 0
        else
           log "#######"
           log "[IN-Progress] SUCC($success_list_num)/ALL($need_check_component_num) ; Deploy ing... "
           log "[DEBUG] In_Progress("${unsuccess_list[*]}"), ALL_component("${need_check_component[*]}"), SUCC_component("${success_list[*]}")"
        fi
        sleep 20
    done

}

function clear_dir(){
    # $1 is dst dir
    # $2 is Retention number

    dstDir=$1
    retentionNum=$2
    n=0

    cd ${dstDir}
    for line in $(ls -tr ${dstDir});do
        [ ${n} -eq 10 ] && log "[INFO] Maximum number of delete times limit.The times is 10"  && break
        FileNum=$(ls ${dstDir} | wc -l)
        if [ $FileNum -le $retentionNum ];then
            log "[INFO] ${dstDir} retention ${retentionNum}.Current file number is $FileNum"
            break
        else
            # find exe
            find ./ -maxdepth 1 -name "${line}" -type d -exec rm -rf {} \;
            ret=$?
            [ $ret -eq 0 ] && log "[INFO] rm dir<$line> done"
            [ $ret -ne 0 ] && log "[ERROR] rm dir<$line> ERROR"  && break
        fi
        let n++
    done
}

### Main ###
clear_dir "{{gvar_component_repo_path}}" "{{gvar_component_retain_num}}"
clear_dir "$tmp_dir" "{{gvar_component_retain_num}}"
check_install_status $cluster_install_namespace
