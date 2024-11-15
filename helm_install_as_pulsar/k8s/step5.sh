#!/bin/bash
#name: step5.sh
#authro: xiangchen
#date: 2023-06-18
#version: v1.0

##################################
# The target of this script is starting service
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
check_env_file "image_registry_secret"
check_env_file "image_registry_url"
check_env_file "image_registry_username"
check_env_file "image_registry_password"
check_env_file "image_registry_email"
check_env_file "image_registry_isDockhub"
check_env_file "image_registry_isPublic"

log "[INFO] check env file Success!"

# used parameters
kubectl_file="$app_service_current/bin/kubectl"
helm_file="$app_service_current/bin/helm"
kubectl_config="$gvar_k8s_config_name"
kubectl_context="$gvar_k8s_config_context"
kubectl_bin="$kubectl_file --kubeconfig=$kubectl_config --context=$kubectl_context "
helm_bin="$helm_file --kubeconfig=$kubectl_config --kube-context=$kubectl_context "

po_release_name="asp-operator"
fm_release_name="function-mesh-operator"
cm_release_name="as-cert-manager"
#asp_release_name="as-platform"
asp_release_name="${gvar_cluster_name}"

# add env extend file
echo "kubectl_file=$kubectl_file" >> $env_extend_file
echo "helm_file=$helm_file" >> $env_extend_file
echo "kubectl_config=$kubectl_config" >> $env_extend_file
echo "kubectl_context=$kubectl_context" >> $env_extend_file
echo "kubectl_bin=\"$kubectl_bin\"" >> $env_extend_file
echo "helm_bin=\"$helm_bin\"" >> $env_extend_file
echo "po_release_name=$po_release_name" >> $env_extend_file
echo "fm_release_name=$fm_release_name" >> $env_extend_file
echo "cm_release_name=$cm_release_name" >> $env_extend_file
echo "asp_release_name=$asp_release_name" >> $env_extend_file

### Main ###
# function #
cd $app_service_current

function check_kubectl_enable() {
    $kubectl_bin api-versions > /dev/null
    ret=$?
    [ $ret -ne 0 ] && log "[ERROR] Kubectl does not execute correctly!PLS check!"  && exit 1
    log "[INFO] check kubectl Success"
}
check_kubectl_enable

function check_helm_enable() {
    $helm_bin list > /dev/null
    ret=$?
    [ $ret -ne 0 ] && log "[ERROR] helm does not execute correctly!PLS check!"  && exit 1
    log "[INFO] check helm Success"
}
check_helm_enable

function check_create_secret() {
    [ $# -ne 1 ] && log "[ERROR]: Need parameter namespace in \$1" && exit 1
    $kubectl_bin get secret -n $1 -o name | grep -E "^secret/${image_registry_secret}$"
    exist_secret_1=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/${image_registry_secret}$" -c)
    if [ $exist_secret_1 -eq 1 ];then
       log "[INFO]: Secret:${image_registry_secret} in $1 is exist."
    else
        if [ "$image_registry_isPublic"x == 'false'x -a "$image_registry_isDockhub"x == 'true'x ];then
            $kubectl_bin create secret docker-registry ${image_registry_secret} --docker-server="https://index.docker.io/v1/" --docker-username=${image_registry_username} --docker-password=${image_registry_password} --docker-email=${image_registry_email}  -n $1; ret=$?
            [ $ret -ne 0 ] && log "[ERROR] create secret  ${image_registry_secret} FAIL" && exit 1
            exist_secret_2=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/${image_registry_secret}$" -c)
            [ $exist_secret_2 -ne 1 ] && log "[ERROR] create secret ${image_registry_secret} FAIL, Namespace:$1 not exist." && exit 1
            [ $exist_secret_2 -eq 1 ] && log "[INFO] create secret ${image_registry_secret}  Success"

        elif [ "$image_registry_isPublic"x == 'false'x -a "$image_registry_isDockhub"x == 'false'x ];then
            $kubectl_bin create secret docker-registry ${image_registry_secret} --docker-server=${image_registry_url} --docker-username=${image_registry_user} --docker-password=${image_registry_passwd} -n $1; ret=$?
            [ $ret -ne 0 ] && log "[ERROR] create secret  ${image_registry_secret} FAIL" && exit 1
            exist_secret_2=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/${image_registry_secret}$" -c)
            [ $exist_secret_2 -ne 1 ] && log "[ERROR] create secret ${image_registry_secret} FAIL, Namespace:$1 not exist." && exit 1
            [ $exist_secret_2 -eq 1 ] && log "[INFO] create secret ${image_registry_secret}  Success"

        else
            log "[INFO]: image registry is public, pass create secret"
        fi
    fi
}


function check_create_namespace() {
    [ $# -ne 1 ] && log "[ERROR]: Need parameter namespace in \$1" && exit 1
    exist_namespace_1=$($kubectl_bin get namespace -o name | grep -E "^namespace/${1}$" -c)
    if [ $exist_namespace_1 -eq 1 ];then
       log "[INFO]: Namespace:$1 is exist."
    else
       $kubectl_bin create namespace $1; ret=$?
       [ $ret -ne 0 ] && log "[ERROR] create namespace $1 FAIL" && exit 1
       exist_namespace_2=$($kubectl_bin get namespace -o name | grep -E "^namespace/${1}$" -c)
       [ $exist_namespace_2 -ne 1 ] && log "[ERROR] create namespace $1 FAIL, Namespace:$1 not exist." && exit 1
       [ $exist_namespace_2 -eq 1 ] && log "[INFO] create namespace $1 Success"
    fi
}

function create_pulsar_operator() {
    # update
    is_install=$($helm_bin test ${po_release_name} -n ${cluster_operator_namespace}  2> /dev/null  | grep -F 'STATUS: deployed' -c)
    if [ ${is_install} -eq 0 ];then
        $helm_bin install ${po_release_name} -n  ${cluster_operator_namespace} --values $app_service_current/as-platform/asp-operator/aso-values.yaml $app_service_current/as-platform/asp-operator/asp-operator.tgz > /dev/null   2>&1
    else
        $helm_bin upgrade ${po_release_name} -n  ${cluster_operator_namespace} --values $app_service_current/as-platform/asp-operator/aso-values.yaml $app_service_current/as-platform/asp-operator/asp-operator.tgz > /dev/null  2>&1
    fi

    sleep 5
    for i in {1..60};
    do
        as_operator_num=$($kubectl_bin get pod -n ${cluster_operator_namespace} | grep -E "^asp-operator" | grep Running -c)
        if [ $as_operator_num -ge 1 ];then
            log "[INFO] asp-operator is running"
            break
        fi
        log "[INFO] check as_operator_num is $as_operator_num"

        [ $i -eq 60 ] && log "[ERROR]: Check pulsar_operator exsist ERROR" && exit 1
        sleep 10
    done
}


function create_cm_operator() {
    is_install=$($helm_bin test ${cm_release_name} -n ${cluster_operator_namespace}  2> /dev/null  | grep -F 'STATUS: deployed' -c)
    if [ ${is_install} -eq 0 ];then
        $kubectl_bin apply -f $app_service_current/as-platform/cert-manager/cert-manager.crds.yaml
        $helm_bin install ${cm_release_name} -n  ${cluster_operator_namespace} --values $app_service_current/as-platform/cert-manager/cm-values.yaml $app_service_current/as-platform/cert-manager/cert-manager.tgz > /dev/null   2>&1
    else
        $kubectl_bin apply -f $app_service_current/as-platform/cert-manager/cert-manager.crds.yaml
        $helm_bin upgrade ${cm_release_name} -n  ${cluster_operator_namespace} --values $app_service_current/as-platform/cert-manager/cm-values.yaml $app_service_current/as-platform/cert-manager/cert-manager.tgz > /dev/null  2>&1
    fi

    sleep 5

    for i in {1..60};do
        cert_manager_num=$($kubectl_bin get pod -n ${cluster_operator_namespace} | grep -E "cert-manager" | grep Running -c )
        if [ $cert_manager_num -ge 3 ];then
            log "[INFO]: Check cm_operator exsist"
            break
        fi
        log "[INFO] check cert_manager_num is $cert_manager_num"

        [ $i -eq 60 ] && log "[ERROR]: Check Cm_operator not exsist,PLS check" && exit 1
        sleep 10
    done

}


function create_fm_operator() {
    is_install=$($helm_bin test ${fm_release_name} -n ${cluster_operator_namespace}  2> /dev/null  | grep -F 'STATUS: deployed' -c)
    if [ ${is_install} -eq 0 ];then
        $helm_bin install ${fm_release_name} -n  ${cluster_operator_namespace} --values $app_service_current/as-platform/function-mesh-operator/fmo-values.yaml  $app_service_current/as-platform/function-mesh-operator/function-mesh-operator.tgz  > /dev/null 2>&1
    else
        $helm_bin upgrade ${fm_release_name} -n  ${cluster_operator_namespace} --values $app_service_current/as-platform/function-mesh-operator/fmo-values.yaml  $app_service_current/as-platform/function-mesh-operator/function-mesh-operator.tgz  > /dev/null 2>&1
    fi

    sleep 5

    for i in {1..60};do
        controller_manager_num=$($kubectl_bin get pod -n ${cluster_operator_namespace} | grep -E "function-mesh-controller-manager" | grep Running -c )

        if [ $controller_manager_num -ge 1 ];then
            log "[INFO] controller manager is running"
            break
        fi
        log "[INFO] check controller_manager_num is $controller_manager_num"

        [ $i -eq 60 ] && log "[ERROR]: Check Fm_operator not exsist,PLS check" && exit 1
        sleep 10
    done

}


function check_jwt_secret() {
    [ $# -ne 2 ] && log "[ERROR]: Need parameter namespace in \$1, release in \$2" && exit 1

    key_symmetric_num=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/$2-token-symmetric-key$" -c )
    [ $key_symmetric_num -eq 1 ] && key_symmetric_num=101

    token_admin_num=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/$2-token-admin$" -c )
    token_broker_admin_num=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/$2-token-broker-admin$" -c )
    token_proxy_admin_num=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/$2-token-proxy-admin$" -c )
    token_pulsar_manager_admin_num=$($kubectl_bin get secret -n $1 -o name | grep -E "^secret/$2-token-pulsar-manager-admin$" -c )
    # 4

    ret_num=$((key_symmetric_num + token_admin_num + token_broker_admin_num + token_proxy_admin_num + token_pulsar_manager_admin_num))
    log "[DEBUG] key_symmetric_num=$key_symmetric_num,token_admin_num=$token_admin_num,token_broker_admin_num=$token_broker_admin_num,token_proxy_admin_num=$token_proxy_admin_num,token_pulsar_manager_admin_num=$token_pulsar_manager_admin_num,ret_num=$ret_num"


    if [ $ret_num -ge 105 ];then
       log "[INFO]:secret-key and token-file are exist"
       return 0
    elif [ $ret_num -eq 0 ];then
       log "[INFO]: Need create secret-key and token-file"
       return 1
    elif [ $ret_num -lt 101 ];then
       log "[ERROR]:secret-key not exist, but token-file exist"
       return 3
    else
       log "[ERROR]: token-file partial existence, Normal token file includes deployments($2-token-admin/$2-token-broker-admin/$2-token-proxy-admin/$2-token-pulsar-manager-admin)"
       return 2
    fi
}

function create_jwt_secret() {
    [ $# -ne 2 ] && log "[ERROR]: Need parameter namespace in \$1, release in \$2" && exit 1

    [ ! -f $app_service_current/scripts/pulsar/prepare_helm_release.sh ] && log "[ERROR] not find scripts in  $app_service_current/scripts/pulsar/prepare_helm_release.sh" && exit 1

    /bin/sh $app_service_current/scripts/pulsar/prepare_helm_release.sh -n $1 -k $2 -s

}

function create_pulsar_cluster() {
    is_install=$($helm_bin test ${asp_release_name} -n ${cluster_install_namespace}  2> /dev/null  | grep -F 'STATUS: deployed' -c)
    if [ ${is_install} -eq 0 ];then
        $helm_bin install ${asp_release_name} -n ${cluster_install_namespace} --set initialize=true  --set namespace=${cluster_install_namespace}  --create-namespace -n ${cluster_install_namespace} --values $app_service_current/as-platform/asp-chart/asp-values.yaml $app_service_current/as-platform/asp-chart/as-platform.tgz  > /dev/null   2>&1
        install_ret=$?;
        [ $install_ret -eq 0 ] && log "[INFO] helm install success!"
        [ $install_ret -ne 0 ] && log "[ERROR] helm install FAIL! CHECK!" && exit 1
    else
        $helm_bin upgrade ${asp_release_name} -n ${cluster_install_namespace} --set initialize=true  --set namespace=${cluster_install_namespace}  --create-namespace -n ${cluster_install_namespace} --values $app_service_current/as-platform/asp-chart/asp-values.yaml $app_service_current/as-platform/asp-chart/as-platform.tgz  > /dev/null  2>&1
        upgrede_ret=$?;
        [ $upgrede_ret -eq 0 ] && log "[INFO] helm upgrede success!"
        [ $upgrede_ret -ne 0 ] && log "[ERROR] helm upgrede FAIL! CHECK!" && exit 1
    fi
}


# main
check_create_namespace $cluster_operator_namespace
check_create_namespace $cluster_install_namespace

check_create_secret $cluster_operator_namespace
check_create_secret $cluster_install_namespace

# pulsar operator
create_pulsar_operator
create_cm_operator
create_fm_operator

# secret key & token
check_jwt_secret $cluster_install_namespace $asp_release_name;check_jwt_secret_ret1=$?
if [ $check_jwt_secret_ret1 -eq 0 ];then
    log "[INFO]check_jwt_secret ret is 0, PASS!"
elif [ $check_jwt_secret_ret1 -eq 1 -o $check_jwt_secret_ret1 -eq 2 ];then
    create_jwt_secret $cluster_install_namespace $asp_release_name
    check_jwt_secret $cluster_install_namespace $asp_release_name;check_jwt_secret_ret2=$?
    [ $check_jwt_secret_ret2 -eq 0 ] && log "[INFO] The secret&token installed Success!"
    [ $check_jwt_secret_ret2 -ne 0 ] && log "[ERROR] The secret&token installed fail" && exit 1
else
    log "[ERROR] check secretKey&token Error,please clean up the error data and try again " && exit 1
fi

# install pulsar
create_pulsar_cluster

log "[INFO] done"

