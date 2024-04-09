#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2023. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CLI_CMD=kubectl
TEMP_FOLDER=${CUR_DIR}/.tmp
TEMP_CP_CONSOLE_FILE=${TEMP_FOLDER}/original-cp-console.yaml
TEMP_CP_CONSOLE_FILE_ID_PROVIDER=${TEMP_FOLDER}/id-provider-cp-console.yaml
TEMP_CP_CONSOLE_FILE_ID_MGMT=${TEMP_FOLDER}/id-mgmt-cp-console.yaml

CP_CONSOLE='cp-console'
ID_PROVIDER_ROUTE_NAME='cp-console-iam-provider'
ID_PROVIDER_PATH='/idprovider/'
ID_MGMT_ROUTE_NAME='cp-console-iam-idmgmt'
ID_MGMT_PATH='/idmgmt/'

CPE_SERVICE_NAME="cpe-stateless-svc"
CPE_SERVICE_PORT="9443"
RUNNABLE_JAR_NAME="cp4ba-scim-upgrade.jar"
CLASS_PATH="/tmp/Jace.jar;/opt/ibm/content_emitter/stax-api.jar;/opt/ibm/content_emitter/xlxpScanner.jar;/opt/ibm/content_emitter/xlxpScannerUtils.jar"

## 
OPERATOR_LABEL="name=ibm-content-operator"
CPE_LABEL="cpe-deploy"
## Jar files section
JACE_NAME="Jace.jar"
STAX_NAME="stax-api.jar"
SCANNER_NAME="xlxpScanner.jar"
SCANNER_UTILS_NAME="xlxpScannerUtils.jar"
TRUSTSTORE_NAME="ibm_customFNCMTrustStore.p12"

JACE_PATH="/opt/ibm/wlp/usr/servers/defaultServer/jaceLib/${JACE_NAME}"
STAX_PATH="/opt/ibm/content_emitter/${STAX_NAME}"
SCANNER_PATH="/opt/ibm/content_emitter/${SCANNER_NAME}"
SCANNER_UTILS_PATH="/opt/ibm/content_emitter/${SCANNER_UTILS_NAME}"
CPE_TRUSTSTORE_PATH="/opt/ibm/wlp/usr/servers/defaultServer/resources/security/${TRUSTSTORE_NAME}"


COMMON_SERVICES_SHARED_NAMESPACE="ibm-common-services"


COLOR_OFF='\033[0m'
#COLORS
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh



# rm -fr $TEMP_CP_CONSOLE_FILE
# ${CLI_CMD} get route $CP_CONSOLE -o yaml > $TEMP_CP_CONSOLE_FILE 
# CP_CONSOLE_HOST=$(${YQ_CMD} r $TEMP_CP_CONSOLE_FILE spec.host )
# ID_MGMT_CP_CONSOLE="id-mgmt-${CP_CONSOLE_HOST}"
# ID_PROVIDER_CP_CONSOLE="id-provider-${CP_CONSOLE_HOST}"


# cp $TEMP_CP_CONSOLE_FILE $TEMP_CP_CONSOLE_FILE_ID_PROVIDER
# cp $TEMP_CP_CONSOLE_FILE $TEMP_CP_CONSOLE_FILE_ID_MGMT

# ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.name "$ID_PROVIDER_ROUTE_NAME"
# ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.path "$ID_PROVIDER_PATH" 
# ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.host "$ID_PROVIDER_CP_CONSOLE"

# ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.ownerReferences
# ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.uid
# ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.resourceVersion
# ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER status
# ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.creationTimestamp
# ${CLI_CMD} apply -f $TEMP_CP_CONSOLE_FILE_ID_PROVIDER

function show_help() {
    echo -e "\nUsage: cp4a-pre-upgrade-and-post-upgrade-optional.sh scim-enabled/pre-upgrade/post-upgrade\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  scim-enabled - Check if SCIM is configured and if pre-upgrade/post-upgrade are needed to be executed for upgrading"
    echo "  pre-upgrade  - Create custom IAM routes prior to upgrading to CP4BA 23.0.1"
    echo "  post-upgrade - Update P8 domain with IAM/IM service after upgrade to CP4BA 23.0.1"
     
}


function check_if_failed(){
  value=$1

  if [[ ${value} != "0" ]]; then
    exit 1
  fi

}

function get_default_cp_console_route() {

  if [ ! -d $TEMP_FOLDER ]; then
    mkdir $TEMP_FOLDER
  fi

  rm -fr $TEMP_CP_CONSOLE_FILE
  local tmp_cp_console=$( ${CLI_CMD} get route $CP_CONSOLE --no-headers --ignore-not-found  -n $TARGET_PROJECT_NAME_CS | awk '{print $1}' )
  if [ -n $tmp_cp_console  ]; then
    echo -e "${BLUE}Creating backup yaml for route $CP_CONSOLE${COLOR_OFF}"
    ${CLI_CMD} get route $CP_CONSOLE -o yaml -n $TARGET_PROJECT_NAME_CS > $TEMP_CP_CONSOLE_FILE
    CP_CONSOLE_HOST=$(${YQ_CMD} r $TEMP_CP_CONSOLE_FILE spec.host )
    ID_MGMT_CP_CONSOLE=$( echo "id-mgmt-${CP_CONSOLE_HOST}" | sed   "s/-$TARGET_PROJECT_NAME_CS//g" )
    ID_PROVIDER_CP_CONSOLE=$( echo "id-provider-${CP_CONSOLE_HOST}" | sed  "s/-$TARGET_PROJECT_NAME_CS//g")
    cp $TEMP_CP_CONSOLE_FILE $TEMP_CP_CONSOLE_FILE_ID_PROVIDER
    cp $TEMP_CP_CONSOLE_FILE $TEMP_CP_CONSOLE_FILE_ID_MGMT
  else
    echo -e "${RED}Could not find the route $CP_CONSOLE${COLOR_OFF}" 
    return 1
  fi

  return 0
}

function create_custom_idprovider_route() {

  if [ -a ${TEMP_CP_CONSOLE_FILE_ID_PROVIDER} ]; then

    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.name "$ID_PROVIDER_ROUTE_NAME"
    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.path "$ID_PROVIDER_PATH"
    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.host "$ID_PROVIDER_CP_CONSOLE"
    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.labels.path "idprovider"


    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.ownerReferences
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.uid
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.resourceVersion
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER status
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER metadata.creationTimestamp

    if [[ "$1" == "platform-identity-provider" ]]; then
      sed -i "s/-$TARGET_PROJECT_NAME_CS//g" $TEMP_CP_CONSOLE_FILE_ID_PROVIDER
      ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.to.name "platform-identity-provider"
      ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER spec.port.targetPort "4300"
      ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_PROVIDER 'metadata.annotations."haproxy.router.openshift.io/rewrite-target"' '/'
    fi

    echo -e "Creating new route named $ID_PROVIDER_ROUTE_NAME"
    ${CLI_CMD} apply -f $TEMP_CP_CONSOLE_FILE_ID_PROVIDER -n $TARGET_PROJECT_NAME_CS
  else
    echo -e "${RED}File not found:${COLOR_OFF} ${TEMP_CP_CONSOLE_FILE_ID_PROVIDER}"
    return -1
  fi

  return 0

}

function create_custom_idmgmt_route() {

  if [ -a ${TEMP_CP_CONSOLE_FILE_ID_MGMT} ]; then

    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.name "$ID_MGMT_ROUTE_NAME"
    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.labels.path "idmgmt"
    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.path "$ID_MGMT_PATH"
    ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.host "$ID_MGMT_CP_CONSOLE"

    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.ownerReferences
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.uid
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.resourceVersion
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT status
    ${YQ_CMD} d -i $TEMP_CP_CONSOLE_FILE_ID_MGMT metadata.creationTimestamp

    if [[ "$1" == "platform-identity-management" ]]; then
       sed -i "s/-$TARGET_PROJECT_NAME_CS//g" $TEMP_CP_CONSOLE_FILE_ID_MGMT
       ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.to.name "platform-identity-management"
       ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT spec.port.targetPort "4500"
       ${YQ_CMD} w -i $TEMP_CP_CONSOLE_FILE_ID_MGMT 'metadata.annotations."haproxy.router.openshift.io/rewrite-target"' '/'

    fi

    echo -e "Creating new route named $ID_MGMT_ROUTE_NAME"
    ${CLI_CMD} apply -f $TEMP_CP_CONSOLE_FILE_ID_MGMT -n $TARGET_PROJECT_NAME_CS
  else
    echo -e "${RED}File not found:${COLOR_OFF} ${TEMP_CP_CONSOLE_FILE_ID_MGMT}"
    return -1
  fi
  
  return 0
   
}

function validate_new_routes() {
  echo -e "${BLUE}Going to validate new custom cp console routes before upgrading${COLOR_OFF}"
  
  local app_login_user=$( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.appLoginUsername }' | base64 -d )
  local app_login_pwd=$( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.appLoginPassword }' | base64 -d )


  local json=$( curl -k -X POST -s -H 'Content-type: application/x-www-form-urlencoded;charset=UTF-8' "https://$ID_PROVIDER_CP_CONSOLE/idprovider/v1/auth/identitytoken"  -d "grant_type=password&scope=openid&username=$app_login_user&password=$app_login_pwd"  ) 

  local access_token=$(echo $json |  ${YQ_CMD} r -P - 'access_token')

  if [[ $access_token != "" ]]; then
    
    echo -e "${BLUE}We were able to successfuly retrive an access token for user ${app_login_user}${COLOR_OFF}"
    echo -e "${BLUE}Waiting 30 seconds before validating route $ID_MGMT_CP_CONSOLE${COLOR_OFF}"
    sleep 30s
    echo -e "${BLUE}With the access_token, we're going to verify if we're able to make a scim call with the host $ID_MGMT_CP_CONSOLE${COLOR_OFF}"
    
    local scim=$(  curl -H "Authorization: Bearer ${access_token}" -k -X GET -s  "https://$ID_MGMT_CP_CONSOLE/idmgmt/identity/api/v1/scim/Users?filter=userName%20eq%20%22${app_login_user}%22&attributes=displayName,name,externalId,groups,id,userName&count=1&searchScope=sp"  )
    local totalResults=$(echo $scim | ${YQ_CMD} r -P - 'totalResults')
    
    if [[ $totalResults == "1" ]]; then
      echo -e "${BLUE}Successfuly retrieve user by using the $ID_MGMT_CP_CONSOLE${COLOR_OFF}"
      return 0
    else
      echo -e "${RED}Unable to retrieve user by using the route $ID_MGMT_CP_CONSOLE${COLOR_OFF}"
      return 1
    fi

  else
    echo -e "${RED}Failed to validate the new cp console routes${COLOR_OFF}"
    return  1
  fi


}


function select_project(){

    while [[ $TARGET_PROJECT_NAME == "" ]];
    do
        if [ -z "$CP4BA_AUTO_NAMESPACE" ]; then
            echo
            # echo -e "\x1B[1mWhere do you want to deploy Cloud Pak for Business Automation?\x1B[0m"
            read -p "Enter the name for an existing project (namespace): " TARGET_PROJECT_NAME
        else
            if [[ "$CP4BA_AUTO_NAMESPACE" == openshift* ]]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                exit 1
            elif [[ "$CP4BA_AUTO_NAMESPACE" == kube* ]]; then
                echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                exit 1
            fi
            TARGET_PROJECT_NAME=$CP4BA_AUTO_NAMESPACE
        fi

        if [ -z "$TARGET_PROJECT_NAME" ]; then
            echo -e "\x1B[1;31mEnter a valid project name, project name can not be blank\x1B[0m"
        elif [[ "$TARGET_PROJECT_NAME" == openshift* ]]; then
            echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
            TARGET_PROJECT_NAME=""
        elif [[ "$TARGET_PROJECT_NAME" == kube* ]]; then
            echo -e "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
            TARGET_PROJECT_NAME=""
        else
            isProjExists=`${CLI_CMD} get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l`  >/dev/null 2>&1

            if [ "$isProjExists" -ne 2 ] ; then
                echo -e "\x1B[1;31mInvalid project name, please enter a existing project name ...\x1B[0m"
                TARGET_PROJECT_NAME=""
            else
                echo -e "\x1B[1mUsing project ${TARGET_PROJECT_NAME}...\x1B[0m"
            fi
        fi
    done
  return 0
}

function check_cs_mode(){
  cs_dedicated=$(kubectl get cm --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_DEDICATED_NAME} | awk '{print $1}')

  cs_shared=$(kubectl get cm --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE}  | grep ${COMMON_SERVICES_CM_SHARED_NAME} | awk '{print $1}')

  if [[ "$cs_dedicated" != "" || "$cs_shared" != ""  ]] ; then
      control_namespace=$( kubectl get cm --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE}  ${COMMON_SERVICES_CM_DEDICATED_NAME} -o jsonpath='{ .data.common-service-maps\.yaml }' | grep  'controlNamespace' | cut -d':' -f2 )
      control_namespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$control_namespace")
      control_namespace=$(sed "s/ //g" <<< $control_namespace)
      map_to_common_svc=$( kubectl get cm --no-headers --ignore-not-found -n ${COMMON_SERVICES_CM_NAMESPACE}  ${COMMON_SERVICES_CM_DEDICATED_NAME} -o jsonpath='{ .data.common-service-maps\.yaml }'  | grep  'map-to-common-service-namespace' | cut -d':' -f2  | awk '{print $1}' )
  fi

  if [[ "$cs_dedicated" != "" && "$cs_shared" == "" ]] || [[ "$cs_dedicated" != "" && "$cs_shared" != "" && "$control_namespace" != "" && "$map_to_common_svc" != "ibm-common-services" ]]; then 
    info "Cloud Pak foundational services is working in dedicated mode, continuing ..."
    TARGET_PROJECT_NAME_CS=$TARGET_PROJECT_NAME
  else
    info "Cloud Pak foundational services is working in shared mode, continuing..."
    TARGET_PROJECT_NAME_CS=$COMMON_SERVICES_SHARED_NAMESPACE
  fi
}

function set_fncm_secret() {

    while [[ $IBM_FNCM_SECRET_NAME  == "" ]];
    do
      # echo -e "\x1B[1mEnter the ibm fncm secret \x1B[0m"
      read -p "Enter the name of ibm fncm secret (ibm-fncm-secret): " IBM_FNCM_SECRET_NAME
      if [[ $IBM_FNCM_SECRET_NAME == "" ]]; then
        IBM_FNCM_SECRET_NAME='ibm-fncm-secret'
      fi

      local ibm_fncm_secret_result=$($CLI_CMD get secret --no-headers --ignore-not-found $IBM_FNCM_SECRET_NAME -n ${TARGET_PROJECT_NAME} | awk '{print $1}')
      if [ -z $ibm_fncm_secret_result ]; then
         echo -e "\x1B[1mInvalid secret name, please enter a valid secret name\x1B[0m"
         IBM_FNCM_SECRET_NAME=""
      fi
    done
  return 0
}


function retrieve_dependencies(){
  # get pods -l 'name=ibm-content-operators' --no-headers --ignore-not-found
  # Check if the content operator exists
  # kubectl get pods | grep  cpe-deploy | head -n 1 | awk '{print $1}'
  local content_operator=$( $CLI_CMD get pods -l "${OPERATOR_LABEL}" --no-headers --ignore-not-found -n $TARGET_PROJECT_NAME | awk '{print $1}' ) 
  local cpe_pod=$( $CLI_CMD get pods -n $TARGET_PROJECT_NAME | grep "${CPE_LABEL}" | head -n 1 | awk '{print $1}' )
  CONTENT_OPERATOR=$content_operator
  # if [ -n $content_operator ]; then
  #   $CLI_CMD cp $content_operator:${STAX_PATH} ${TEMP_FOLDER}/${STAX_NAME}
  #   $CLI_CMD cp $content_operator:${SCANNER_PATH} ${TEMP_FOLDER}/${SCANNER_NAME}
  #   $CLI_CMD cp $content_operator:${SCANNER_UTILS_PATH} ${TEMP_FOLDER}/${SCANNER_UTILS_NAME} 
  # else
  #   return 1
  # fi

  if [[ ${cpe_pod} != ""  ]]; then
    $CLI_CMD cp $cpe_pod:${JACE_PATH} ${TEMP_FOLDER}/${JACE_NAME}  >/dev/null 2>&1 
    $CLI_CMD cp $cpe_pod:${CPE_TRUSTSTORE_PATH} ${TEMP_FOLDER}/${TRUSTSTORE_NAME}  >/dev/null 2>&1
  else
    return 1
  fi

  if [[  ${content_operator} != "" ]]; then
    $CLI_CMD cp ${TEMP_FOLDER}/${JACE_NAME}  $content_operator:/tmp/${JACE_NAME}  >/dev/null 2>&1 
    $CLI_CMD cp ${TEMP_FOLDER}/${TRUSTSTORE_NAME} $content_operator:/tmp/${TRUSTSTORE_NAME}  >/dev/null 2>&1
    $CLI_CMD cp ${CUR_DIR}/helper/$RUNNABLE_JAR_NAME  $content_operator:/tmp/${RUNNABLE_JAR_NAME}  >/dev/null 2>&1 
  else
    return 1
  fi

  return 0
}

function decode_xor() {

  local encoded=$1
  local was_home="/opt/ibm/securityUtility"
  local class_path="${was_home}/plugins/com.ibm.ws.runtime.jar:${was_home}/lib/bootstrap.jar:${was_home}/plugins/com.ibm.ws.emf.jar:${was_home}/lib/ffdc.jar:${was_home}/plugins/org.eclipse.emf.ecore.jar:${was_home}/plugins/org.eclipse.emf.common.jar:${was_home}/glassfish-corba-omgapi-4.2.4.jar"
  if [[ $encoded != "" ]] && [[ "$encoded" == *"{xor}"* ]]; then
    local decoded=$( ${CLI_CMD} exec -i -n $TARGET_PROJECT_NAME $CONTENT_OPERATOR -- bash -c "java -cp \"${class_path}\" com.ibm.ws.security.util.PasswordDecoder \"$encoded\"")
    echo "$decoded" | grep -i 'decoded password == ' | awk '{print $8}' | sed -e 's/^"//' -e 's/"$//'
  else
    echo $encoded
  fi
}

function update_acce(){

  local app_login_user=$( decode_xor $( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.appLoginUsername }' | base64 -d ) )
  local app_login_pwd=$( decode_xor $( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.appLoginPassword }' | base64 -d ) )
  local key_store_pass=$( decode_xor $( $CLI_CMD get secret $IBM_FNCM_SECRET_NAME -n $TARGET_PROJECT_NAME -o jsonpath='{ .data.keystorePassword }' | base64 -d ) )
  local cpe_svc_name=$( $CLI_CMD get svc -n $TARGET_PROJECT_NAME | grep $CPE_SERVICE_NAME | awk '{print $1}' )
  local class_path="/tmp/Jace.jar;/opt/ibm/content_emitter/stax-api.jar;/opt/ibm/content_emitter/xlxpScanner.jar;/opt/ibm/content_emitter/xlxpScannerUtils.jar"
  local option=$1

  if [[ $option == "POSTUPGRADE" ]]; then 
    echo "Executing POSTUPGRADE"
    ${CLI_CMD} exec -i -n $TARGET_PROJECT_NAME $CONTENT_OPERATOR -- bash -c "java -cp \"${CLASS_PATH}\" -jar -Duser.language=en -Duser.country=US -Djavax.net.ssl.trustStore=/tmp/ibm_customFNCMTrustStore.p12 -Djavax.net.ssl.trustStoreType=pkcs12  -Djavax.net.ssl.trustStorePassword=${key_store_pass} /tmp/${RUNNABLE_JAR_NAME} $option $cpe_svc_name.$TARGET_PROJECT_NAME.svc $CPE_SERVICE_PORT $app_login_user  $app_login_pwd  $TARGET_PROJECT_NAME_CS $ID_MGMT_CP_CONSOLE $ID_PROVIDER_CP_CONSOLE"

  elif [[ $option == "SCIMENABLED" ]]; then 
    ${CLI_CMD} exec -i -n $TARGET_PROJECT_NAME $CONTENT_OPERATOR -- bash -c "java -cp \"${CLASS_PATH}\" -jar -Duser.language=en -Duser.country=US -Djavax.net.ssl.trustStore=/tmp/ibm_customFNCMTrustStore.p12 -Djavax.net.ssl.trustStoreType=pkcs12  -Djavax.net.ssl.trustStorePassword=${key_store_pass} /tmp/${RUNNABLE_JAR_NAME} $option $cpe_svc_name.$TARGET_PROJECT_NAME.svc $CPE_SERVICE_PORT $app_login_user  $app_login_pwd  $TARGET_PROJECT_NAME_CS"

  elif [[ $option == "PREUPGRADE" ]]; then
    ${CLI_CMD} exec -i -n $TARGET_PROJECT_NAME $CONTENT_OPERATOR -- bash -c "java -cp \"${CLASS_PATH}\" -jar -Duser.language=en -Duser.country=US -Djavax.net.ssl.trustStore=/tmp/ibm_customFNCMTrustStore.p12 -Djavax.net.ssl.trustStoreType=pkcs12  -Djavax.net.ssl.trustStorePassword=${key_store_pass} /tmp/${RUNNABLE_JAR_NAME} $option $cpe_svc_name.$TARGET_PROJECT_NAME.svc $CPE_SERVICE_PORT $app_login_user  $app_login_pwd  $TARGET_PROJECT_NAME_CS $ID_MGMT_CP_CONSOLE $ID_PROVIDER_CP_CONSOLE"
  fi


}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    if [[ $1 == "scim-enabled" ]]; then
      opt="scimenabled"

    elif [[ $1 == "pre-upgrade" ]]; then
      opt="preupgrade"

    elif [[ $1 == "post-upgrade" ]]; then
      opt="postupgrade"
    else
      opt='-h'
    fi

    case "$opt" in
    h|\?|-h)
        show_help
        exit 0
        ;;
    preupgrade)
        select_project 
        res=$?
        if [[ ${res} == "0" ]]; then
          check_cs_mode
          set_fncm_secret
          res=$?
          if [[ ${res} == "0" ]]; then
            get_default_cp_console_route
            res=$?
              if [[ ${res} == "0" ]]; then
                create_custom_idprovider_route
                res=$?
                create_custom_idmgmt_route
                res2=$?
                validate_new_routes
                res3=$?
                if [[ ${res} == "0" ]] && [[ ${res2} == "0" ]] && [[ ${res3} == "0" ]]; then
                  retrieve_dependencies
                  res=$?
                  if [[ ${res} == "0" ]]; then
                    update_acce PREUPGRADE $ID_MGMT_CP_CONSOLE $ID_PROVIDER_CP_CONSOLE

                  else
                    exit 1
                  fi
                else 
                  echo "${RED}Failed to create the new custom routes${COLOR_OFF}"
                  exit 1
                fi 
              else
                echo "${RED}Failed to retrieve cp console route${COLOR_OFF}"
                exit 1
              fi
          else
            echo "${RED}Failed to retrieve ibm fncm secret${COLOR_OFF}"
            exit 1
          fi
        else
          echo "Failed to get set namespace" 
          exit 1
        fi 

        ;;
    postupgrade)
        select_project
        res=$?
        if [[ ${res} == "0" ]]; then
          check_cs_mode
          set_fncm_secret
          res=$?
          if [[ ${res} == "0" ]]; then
            get_default_cp_console_route
            res=$?
              if [[ ${res} == "0" ]]; then
                create_custom_idprovider_route "platform-identity-provider"
                res=$?
                create_custom_idmgmt_route "platform-identity-management"
                # retrieve_dependencies
                res2=$?
                if [[ ${res} == "0" ]] && [[ ${res2} == "0" ]]; then
                  retrieve_dependencies
                  res=$?
                  if [[ ${res} == "0" ]]; then
                    update_acce POSTUPGRADE

                  else
                    exit 1
                  fi
                else
                  echo "${RED}Failed to create the new custom routes${COLOR_OFF}"
                  exit 1
                fi
              else
                echo "${RED}Failed to retrieve cp console route${COLOR_OFF}"
                exit 1
              fi
          else
            echo "${RED}Failed to retrieve ibm fncm secret${COLOR_OFF}"
            exit 1
          fi
        else
          echo "Failed to get set namespace"
          exit 1
        fi
        ;;

    scimenabled)
        select_project
        res=$?
        if [[ ${res} == "0" ]]; then
          check_cs_mode
          set_fncm_secret
          res=$?
          if [[ ${res} == "0" ]]; then
            retrieve_dependencies
            res=$?
            if [[ ${res} == "0" ]]; then
              update_acce SCIMENABLED
            else
              echo -e "${RED}Failed to retrieve dependencies${COLOR_OFF}"
              exit 1
            fi
          else
            echo "${RED}Failed to retrieve ibm fncm secret${COLOR_OFF}"
            exit 1
          fi
        else
          echo "Failed to get set namespace"
          exit 1
        fi
        ;;

    :)  echo "Invalid option: requires an argument"
        show_help
        exit -1
        ;;
    esac
fi




