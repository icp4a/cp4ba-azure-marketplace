#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
# CUR_DIR set to full path to scripts folder
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/op-olm/subscription.yaml
OLM_SUBSCRIPTION_TMP=${TEMP_FOLDER}/.subscription.yaml


TEMP_FOLDER=${CUR_DIR}/.tmp
BAK_FOLDER=${CUR_DIR}/.bak
mkdir -p $TEMP_FOLDER >/dev/null 2>&1
mkdir -p $BAK_FOLDER >/dev/null 2>&1

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

OPERATOR_PVC_FILE=${PARENT_DIR}/descriptors/operator-shared-pvc.yaml
OPERATOR_PVC_FILE_TMP1=$TEMP_FOLDER/.operator-shared-pvc_tmp1.yaml
OPERATOR_PVC_FILE_TMP=$TEMP_FOLDER/.operator-shared-pvc_tmp.yaml
OPERATOR_PVC_FILE_BAK=$BAK_FOLDER/.operator-shared-pvc.yaml

OLM_OPT_GROUP=${PARENT_DIR}/descriptors/op-olm/operator_group.yaml
OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/op-olm/subscription.yaml

OLM_CATALOG_TMP=${TEMP_FOLDER}/.catalog_source.yaml
OLM_OPT_GROUP_TMP=${TEMP_FOLDER}/.operator_group.yaml
OLM_SUBSCRIPTION_TMP=${TEMP_FOLDER}/.subscription.yaml
LICENSE_FILE=${PARENT_DIR}/LICENSE
LICENSE_ACCEPTED=""
CATALOG_FOUND="Yes"

function show_help {
    echo -e "\nPrerequisite:"
    echo -e "1. Login your cluster and switch to your target project;"
    echo -e "2. CR was applied in your project."
    echo -e "3. Upgrade IBM Cloud Pak foundational services according to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=2301-option-2-upgrading-operators-in-online-environment"
    echo -e "\nUsage for OCP and ROKS platform: upgradeOperator.sh -a accept -n namespace"
    echo -e "Usage for other platform: upgradeOperator.sh -a accept -n namespace -i operator_image -p secret_name\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -n  The namespace to deploy Operator"
    echo "  -a  Accept IBM license"
    echo "  -i  Optional: Operator image name, by default it is cp.icr.io/cp/cp4a/icp4a-operator:22.0.1"
    echo -e "  -p  Optional: Pull secret to use to connect to the registry, by default it is ibm-entitlement-key\n"

}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:p:a:n:m:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        p)  PULLSECRET=$OPTARG
            ;;
        n)  NAMESPACE=$OPTARG
            ;;
        a)  LICENSE_ACCEPTED=$OPTARG
            ;;
        m)  RUNTIME_MODE=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

if [ -z "$NAMESPACE" ]; then
  echo -e "\x1B[1;31mPlease input value for \"-n <NAMESPACE>\" option.\n\x1B[0m"
  exit 1
fi

[ -f ${CUR_DIR}/../upgradeOperator.yaml ] && rm ${CUR_DIR}/../upgradeOperator.yaml
cp ${CUR_DIR}/../descriptors/operator.yaml ${CUR_DIR}/../upgradeOperator.yaml

PLATFORM_SELECTED=$(eval echo $(kubectl get icp4acluster $(kubectl get icp4acluster -n $NAMESPACE | grep NAME -v | awk '{print $1}') -n $NAMESPACE -o yaml | grep sc_deployment_platform | tail -1 | cut -d ':' -f 2))
if [[ !($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "ROKS" || $PLATFORM_SELECTED == "other") ]]; then
  clear
  echo -e "\x1B[1;31mA deployed custom resource cannot be found.\n\x1B[0m"
  echo -e "\x1B[1;31mYou must apply an instance of a custom resource before you can upgrade. The script is exiting...\n\x1B[0m"
  exit 1
fi

# Show license file
function readLicense() {
    echo -e "\033[32mYou need to read the International Program License Agreement before start\033[0m"
    sleep 3
    more ${LICENSE_FILE}
}

# Get user's input on whether accept the license
function userInput() {
  while true; do
      echo -e "\033[32mDo you accept the International Program License?(Yes/No): \033[0m"
      read -rp "" ans
      case "$ans" in
      "y"|"Y"|"yes"|"Yes"|"YES")
          LICENSE_ACCEPTED="accept"
          break
          ;;
      "n"|"N"|"no"|"No"|"NO")
          echo -e "\033[31mScript will exit ...\033[0m"
          sleep 2
          exit 0
          ;;
      *)
          echo -e "Answer must be \"Yes\" or \"No\"\n"
          ;;
      esac
  done
}


function prepare_olm_install() {
    local maxRetry=20
    project_name=$NAMESPACE

    if [[ $CATALOG_FOUND == "Yes" ]]; then
        if [[ $PINNED == "Yes" ]]; then
          echo "Found ibm CP4BA operator catalog source, updating it ..."
          oc apply -f $OLM_CATALOG >/dev/null 2>&1
          if [ $? -eq 0 ]; then
            echo "IBM CP4BA Operator Catalog source Updated!"
          else
            echo "IBM CP4BA Operator catalog source update failed"
            exit 1
          fi
          kubectl apply -f ${CUR_DIR}/../descriptors/service_account.yaml --validate=false
          kubectl apply -f ${CUR_DIR}/../descriptors/role.yaml --validate=false
          kubectl apply -f ${CUR_DIR}/../descriptors/role_binding.yaml --validate=false
          kubectl apply -f ${CUR_DIR}/../upgradeOperator.yaml --validate=false
        fi
    else
        oc apply -f $OLM_CATALOG >/dev/null 2>&1
        if [ $? -eq 0 ]; then
          echo "IBM CP4BA Operator Catalog source created!"
        else
          echo "IBM CP4BA Operator catalog source creation failed"
          exit 1
        fi
    fi

    echo "Waiting for CP4BA Operator Catalog pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
      isReady=$(oc get pod -n openshift-marketplace --no-headers | grep $online_source | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then
          echo "Timeout Waiting for  CP4BA Operator Catalog pod to start"
          echo -e "\x1B[1mPlease check the status of Pod by issue cmd: \x1B[0m"
          echo "oc describe pod $(oc get pod -n openshift-marketplace|grep $online_source|awk '{print $1}') -n openshift-marketplace"
          exit 1
        else
          sleep 30
          echo -n "..."
          continue
        fi
      else
        echo "CP4BA Operator Catalog is running $isReady"
        break
      fi
    done

    if [[ $(oc get og -n "${project_name}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
        echo "Found operator group"
        oc get og -n "${project_name}"
    else
      sed "s/REPLACE_NAMESPACE/$project_name/g" ${OLM_OPT_GROUP} > ${OLM_OPT_GROUP_TMP}
      oc apply -f ${OLM_OPT_GROUP_TMP} -n $NAMESPACE
      if [ $? -eq 0 ]
         then
         echo "CP4BA Operator Group Created!"
       else
         echo "CP4BA Operator Operator Group creation failed"
       fi
    fi

    old_pod=$(oc get pods -n $NAMESPACE|grep ibm-cp4a-operator|awk '{print $1}'|head -n 1)
    if [[ $CATALOG_FOUND == "No" ]]; then
      sed "s/REPLACE_NAMESPACE/$project_name/g" ${OLM_SUBSCRIPTION} > ${OLM_SUBSCRIPTION_TMP}
      ${YQ_CMD} w -i ${OLM_SUBSCRIPTION_TMP} spec.source "$online_source"
      oc apply -f ${OLM_SUBSCRIPTION_TMP} -n $NAMESPACE
      # sed <"${OLM_SUBSCRIPTION}" "s|REPLACE_NAMESPACE|${project_name}|g; s|REPLACE_CHANNEL_NAME|stable|g" | oc apply -f -
      if [ $? -eq 0 ]
      then
          echo "CP4BA Operator Subscription Created!"
      else
          echo "CP4BA Operator Subscription creation failed"
          exit 1
      fi
    fi
    if [[ $RUNTIME_MODE == "baw-dev" || $RUNTIME_MODE == "baw" ]];then
      sub_inst_list=$(oc get subscriptions.operators.coreos.com -n $NAMESPACE|grep ibm-|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
      #sub_inst_list=$(oc get subscriptions.operators.coreos.com -n $NAMESPACE|grep ibm-cp4a-|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
      sub_array=($sub_inst_list)
      for i in ${!sub_array[@]}; do
          if [[ ! -z "${sub_array[i]}" ]]; then
            if [[ ${sub_array[i]} = ibm-baw-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = ibm-pfs-operator* ]]; then
              oc patch subscriptions.operators.coreos.com ${sub_array[i]} -n $NAMESPACE -p '{"spec":{"channel":"v23.2"}}' --type=merge >/dev/null 2>&1
              if [ $? -eq 0 ]
              then
                  echo "Update the channel of subsciption '${sub_array[i]}' to 23.2!"
                  printf "\n"
              else
                  echo "Failed to update the channel of subsciption '${sub_array[i]}' to 23.2! exiting now..."
                  exit 1
              fi
            fi
          else
              echo "No found subsciption '${sub_array[i]}'! exiting now..."
              exit 1
          fi
      done
    else
      sub_inst_list=$(oc get subscriptions.operators.coreos.com -n $NAMESPACE|grep ibm-cp4a-|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
      #sub_inst_list=$(oc get subscriptions.operators.coreos.com -n $NAMESPACE|grep ibm-cp4a-|awk '{if(NR>0){if(NR==1){ arr=$1; }else{ arr=arr" "$1; }} } END{ print arr }')
      sub_array=($sub_inst_list)
      for i in ${!sub_array[@]}; do
          if [[ ! -z "${sub_array[i]}" ]]; then
            if [[ ${sub_array[i]} = ibm-cp4a-operator* || ${sub_array[i]} = ibm-cp4a-wfps-operator* || ${sub_array[i]} = ibm-content-operator* || ${sub_array[i]} = icp4a-foundation-operator* || ${sub_array[i]} = ibm-pfs-operator* ]]; then
              oc patch subscriptions.operators.coreos.com ${sub_array[i]} -n $NAMESPACE -p '{"spec":{"channel":"v23.2"}}' --type=merge >/dev/null 2>&1
              if [ $? -eq 0 ]
              then
                  echo "Update the channel of subsciption '${sub_array[i]}' to 23.2!"
                  printf "\n"
              else
                  echo "Failed to update the channel of subsciption '${sub_array[i]}' to 23.2! exiting now..."
                  exit 1
              fi
            fi
          else
              echo "No found subsciption '${sub_array[i]}'! exiting now..."
              exit 1
          fi
      done
    fi

    echo "Waiting for CP4BA operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
      isReady=$(oc get pod -n "$project_name" --no-headers | grep ibm-cp4a-operator | grep "Running")
      new_pod=$(oc get pods -n $NAMESPACE|grep ibm-cp4a-operator|awk '{print $1}'|head -n 1)
      if [[ -z $isReady || "$old_pod" == "$new_pod" ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then
          echo "Timeout Waiting for CP4BA operator to start"
          echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
          echo "oc describe pod $(oc get pod -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
          printf "\n"
          echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
          echo "oc describe rs $(oc get rs -n $project_name|grep ibm-cp4a-operator|awk '{print $1}') -n $project_name"
          printf "\n"
          exit 1
        else
          sleep 30
          echo -n "..."
          continue
        fi
      else
        echo "CP4A operator is running $isReady"
        break
      fi
    done

    echo "Waiting for CP4BA Content operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
      isReady=$(oc get pod -n "$project_name" --no-headers | grep ibm-content-operator | grep "Running")
      # new_pod=$(oc get pods -n $NAMESPACE|grep ibm-content-operator|awk '{print $1}'|head -n 1)
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then
          echo "Timeout Waiting for CP4BA Content operator to start"
          echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
          echo "oc describe pod $(oc get pod -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
          printf "\n"
          echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
          echo "oc describe rs $(oc get rs -n $project_name|grep ibm-content-operator|awk '{print $1}') -n $project_name"
          printf "\n"
          exit 1
        else
          sleep 30
          echo -n "..."
          continue
        fi
      else
        echo "CP4A Content operator is running $isReady"
        break
      fi
    done
}

function uninstall_cp4a(){
    printf "\n"
    printf "\x1B[1mUnDeploying the previous CP4A Operator...\n\x1B[0m"
    kubectl delete -f ${CUR_DIR}/../descriptors/operator.yaml >/dev/null 2>&1
    kubectl delete -f ${CUR_DIR}/../descriptors/role_binding.yaml >/dev/null 2>&1
    kubectl delete -f ${CUR_DIR}/../descriptors/role.yaml >/dev/null 2>&1
    kubectl delete -f ${CUR_DIR}/../descriptors/service_account.yaml >/dev/null 2>&1
    echo "All descriptors have been successfully deleted."
}

function uninstall_olm_cp4a(){
    local csvName
    printf "\n"
    printf "\x1B[1mUninstall CP4A Operator Subscription...\n\x1B[0m"
    ${COPY_CMD} -rf "${OLM_SUBSCRIPTION}" "${OLM_SUBSCRIPTION_TMP}"
    ${SED_COMMAND} '/namespace: /d' ${OLM_SUBSCRIPTION_TMP}
    csvName=$(oc get subscriptions.operators.coreos.com "ibm-cp4a-operator-catalog-subscription" -n $NAMESPACE -o go-template --template '{{.status.installedCSV}}')
    # - remove the subscription
    kubectl delete -f ${OLM_SUBSCRIPTION_TMP} -n $NAMESPACE >/dev/null 2>&1
    # - remove the CSV which was generated by the subscription but does not get garbage collected
    kubectl delete clusterserviceversion "${csvName}" -n $NAMESPACE >/dev/null 2>&1
    echo "The CP4A Operator Subscription has been successfully deleted."
}

function create_new_shared_logs_pvc(){
    if [[ $(kubectl get icp4acluster) == '' ]]; then
        echo -e "\033[31mIf you don't have a CR deployed, we can't upgrade CP4A Operator only, pls run deleteOperator.sh and then deployOperator.sh to redeploy Operator.\033[0m"
        exit 1
    fi
    DEPLOYMENT_TYPE=$(eval echo $(kubectl get icp4acluster $(kubectl get icp4acluster | grep NAME -v | awk '{print $1}') -o yaml | grep sc_deployment_type | tail -1 | cut -d ':' -f 2))
    STORAGE_CLASS_NAME=$(eval echo $(kubectl get icp4acluster $(kubectl get icp4acluster | grep NAME -v | awk '{print $1}') -o yaml | grep sc_dynamic_storage_classname | tail -1 | cut -d ':' -f 2))
    SLOW_STORAGE_CLASS_NAME=$(eval echo $(kubectl get icp4acluster $(kubectl get icp4acluster | grep NAME -v | awk '{print $1}') -o yaml | grep sc_slow_file_storage_classname | tail -1 | cut -d ':' -f 2))
    FAST_STORAGE_CLASS_NAME=$(eval echo $(kubectl get icp4acluster $(kubectl get icp4acluster | grep NAME -v | awk '{print $1}') -o yaml | grep sc_fast_file_storage_classname | tail -1 | cut -d ':' -f 2))
    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        CLI_CMD=oc
    else
        CLI_CMD=kubectl
    fi
    ${COPY_CMD} -rf "${OPERATOR_PVC_FILE}" "${OPERATOR_PVC_FILE_BAK}"
    allocate_operator_pvc
}

function cncf_install(){
  sed -e '/dba_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  sed -e '/baw_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  sed -e '/fncm_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  sed -e '/ier_license/{n;s/value:.*/value: accept/;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml

  if [ ! -z ${IMAGEREGISTRY} ]; then
  # Change the location of the image
  echo "Using the operator image name: $IMAGEREGISTRY"
  sed -e "s|image: .*|image: \"$IMAGEREGISTRY\" |g" ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  fi

  # Change the pullSecrets if needed
  if [ ! -z ${PULLSECRET} ]; then
      echo "Setting pullSecrets to $PULLSECRET"
      sed -e "s|ibm-entitlement-key|$PULLSECRET|g" ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  else
      sed -e '/imagePullSecrets:/{N;d;}' ${CUR_DIR}/../upgradeOperator.yaml > ${CUR_DIR}/../upgradeOperatorsav.yaml ;  mv ${CUR_DIR}/../upgradeOperatorsav.yaml ${CUR_DIR}/../upgradeOperator.yaml
  fi
  kubectl apply -f ${CUR_DIR}/../descriptors/service_account.yaml --validate=false
  kubectl apply -f ${CUR_DIR}/../descriptors/role.yaml --validate=false
  kubectl apply -f ${CUR_DIR}/../descriptors/role_binding.yaml --validate=false
  kubectl apply -f ${CUR_DIR}/../upgradeOperator.yaml --validate=false
}

function cp4a_operator_uninstall(){
  if [[ $(kubectl get deployment -n $NAMESPACE --no-headers | grep ibm-cp4a-operator | awk '{print $1}') != 0 ]]; then
    kubectl delete deployment $(kubectl get deployment -n $NAMESPACE --no-headers | grep ibm-cp4a-operator | awk '{print $1}') -n $NAMESPACE
  fi

  local maxRetry=20
  for ((retry=0;retry<=${maxRetry};retry++)); do
      echo "Waiting for CP4A operator pod to be removed...."

      isReady=$(oc get pod -n "$NAMESPACE" | grep ibm-cp4a-operator )
      if [[ -z $isReady ]]; then
        echo "CP4A operator deleted!"
        break
      else
        if [[ $retry -eq ${maxRetry} ]]; then
          echo -e "\x1B[1;31mTimeout Waiting for CP4A operator to be removed!\n\x1B[0m"
          exit 1
        else
          sleep 30
          continue
        fi
      fi
    done
}

# Check existing catalog source is pinned or non pinned
if [[ -z $RUNTIME_MODE || $RUNTIME_MODE == "baw" ]]; then
  if oc get catalogsource -n openshift-marketplace | grep ibm-operator-catalog; then
    CATALOG_FOUND="Yes"
    PINNED="No"
  elif oc get catalogsource -n openshift-marketplace | grep ibm-cp4a-operator-catalog; then
    CATALOG_FOUND="Yes"
    PINNED="Yes"
  else
    CATALOG_FOUND="No"
    PINNED="Yes" # Fresh install use pinned catalog source
  fi
elif [[ $RUNTIME_MODE == "dev" || $RUNTIME_MODE == "baw-dev" ]]; then
  if oc get catalogsource -n openshift-marketplace | grep ibm-cp4a-operator-catalog; then
    CATALOG_FOUND="Yes"
    PINNED="Yes"
  else
    CATALOG_FOUND="No"
    PINNED="Yes" # Fresh install use pinned catalog source
  fi
fi

if [[ $PINNED == "Yes" ]];then
  if [[ $RUNTIME_MODE == "dev" ]]; then
      OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
      online_source="ibm-cp4a-operator-catalog"
  elif [[ $RUNTIME_MODE == "baw-dev" ]];then
      OLM_CATALOG=${PARENT_DIR}/descriptors/baw-olm/cp4a_catalogsource_dev.yaml
      OLM_OPT_GROUP=${PARENT_DIR}/descriptors/baw-olm/operator_group.yaml
      OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/baw-olm/devsubscription.yaml
      online_source="ibm-baw-operator-catalog"
  elif [[ $RUNTIME_MODE == "baw" ]];then
      OLM_CATALOG=${PARENT_DIR}/descriptors/baw-olm/catalog_source.yaml
      OLM_OPT_GROUP=${PARENT_DIR}/descriptors/baw-olm/operator_group.yaml
      OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/baw-olm/subscription.yaml
      online_source="ibm-operator-catalog"
  elif [[ -z $RUNTIME_MODE ]]; then
      OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
      online_source="ibm-cp4a-operator-catalog"
  fi
elif [[ $PINNED == "No" ]];then
  if [[ $RUNTIME_MODE == "dev" ]]; then
      OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
      online_source="ibm-cp4a-operator-catalog"
  elif [[ $RUNTIME_MODE == "baw-dev" ]];then
      OLM_CATALOG=${PARENT_DIR}/descriptors/baw-olm/cp4a_catalogsource_dev.yaml
      OLM_OPT_GROUP=${PARENT_DIR}/descriptors/baw-olm/operator_group.yaml
      OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/baw-olm/devsubscription.yaml
      online_source="ibm-baw-operator-catalog"
  elif [[ $RUNTIME_MODE == "baw" ]];then
      OLM_CATALOG=${PARENT_DIR}/descriptors/baw-olm/catalog_source.yaml
      OLM_OPT_GROUP=${PARENT_DIR}/descriptors/baw-olm/operator_group.yaml
      OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/baw-olm/subscription.yaml
      online_source="ibm-operator-catalog"
  elif [[ -z $RUNTIME_MODE ]]; then
      OLM_CATALOG=${PARENT_DIR}/descriptors/op-olm/catalog_source.yaml
      online_source="ibm-operator-catalog"
  fi
fi

if [[ $LICENSE_ACCEPTED == "" ]]; then
  readLicense
  userInput
fi

if [[ $LICENSE_ACCEPTED == "accept" ]]; then
  if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ocp" || "$PLATFORM_SELECTED" == "ROKS" || "$PLATFORM_SELECTED" == "roks" ]]; then

    if [[ $RUNTIME_MODE == "baw" || $RUNTIME_MODE == "baw-dev" ]];then
      kubectl get subscriptions.operators.coreos.com -n $NAMESPACE| grep ibm-baw-operator >/dev/null 2>&1
    else
      kubectl get subscriptions.operators.coreos.com -n $NAMESPACE| grep ibm-cp4a-operator-catalog >/dev/null 2>&1
    fi

    returnValue=$?
    if [[ "$returnValue" == 1 ]] ; then
        uninstall_cp4a
    fi
    # cp4a_operator_uninstall
    # uninstall_cp4a
    prepare_olm_install
  else
    cncf_install
  fi
  echo -e "\033[32mAll descriptors have been successfully applied. Monitor the pod status with 'kubectl get pods -w'.\033[0m"
fi
