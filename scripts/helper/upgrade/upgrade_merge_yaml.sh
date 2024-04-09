# Directory for upgrade deployment for CP4BA multiple deployment
UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$1
UPGRADE_DEPLOYMENT_PROPERTY_FILE=${UPGRADE_DEPLOYMENT_FOLDER}/cp4ba_upgrade.property

UPGRADE_DEPLOYMENT_CR=${UPGRADE_DEPLOYMENT_FOLDER}/custom_resource
UPGRADE_DEPLOYMENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR}/backup

UPGRADE_DEPLOYMENT_CONTENT_CR=${UPGRADE_DEPLOYMENT_CR}/content.yaml
UPGRADE_DEPLOYMENT_CONTENT_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.content_tmp.yaml
UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/content_cr_backup.yaml

UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR=${UPGRADE_DEPLOYMENT_CR}/icp4acluster.yaml
UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.icp4acluster_tmp.yaml
UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/icp4acluster_cr_backup.yaml

UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps.yaml
UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_tmp.yaml
UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_backup.yaml

UPGRADE_CS_ZEN_FILE=${UPGRADE_DEPLOYMENT_CR}/.cs_zen_parameter.yaml
UPGRADE_DEPLOYMENT_BAI_TMP=${UPGRADE_DEPLOYMENT_CR}/.bai_tmp.yaml

function create_upgrade_property(){

    mkdir -p ${UPGRADE_DEPLOYMENT_FOLDER}

cat << EOF > ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}
##############################################################################
## The property is for Zen Customize configuration used by CS4.0            ##
##############################################################################
## The namespace for Common Service Operator in CS4.0
CS_OPERATOR_NAMESPACE=""

## The namespace for Common Service in CS4.0
CS_SERVICES_NAMESPACE=""
EOF
  create_zen_yaml
  success "Created CP4BA upgrade property file\n"

}

function create_zen_yaml(){
    mkdir -p ${UPGRADE_DEPLOYMENT_CR}
cat << EOF > ${UPGRADE_CS_ZEN_FILE}
spec:
  shared_configuration:
    sc_common_service:
      ## common service operator namespace for CS4.0
      operator_namespace: ""
      ## common service service namespace for CS4.0
      services_namespace: ""
EOF
}

function select_apply_cr(){
    printf "\n"
    while true; do
        echo "${YELLOW_TEXT}[TIP]: If you want to review or customize the new custom resource before applying it, then select Yes to the following question.${RESET_TEXT}"
        printf "\n"
        printf "\x1B[1mDo you want to edit the new version of the custom resource with some custom settings?\n\x1B[0m"
        printf "If you select Yes, the script displays the next actions to update the custom resource and to apply it. If you select No, the script applies the custom resource automatically.\n"
        printf "(Yes/No, default: Yes): "

        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            APPLY_UPDATED_CR="No"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            APPLY_UPDATED_CR="Yes"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function upgrade_deployment(){
    local project_name=$1
    mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
    # trap 'startup_operator $project_name' EXIT
    shutdown_operator $project_name
    # # Get ZEN property value from UPGRADE_DEPLOYMENT_PROPERTY_FILE
    # ZEN_ROUTE_HOST=$(prop_upgrade_property_file ZEN_ROUTE_HOST)
    # ZEN_ROUTE_CERT=$(prop_upgrade_property_file ZEN_ROUTE_CERT)
    # ZEN_ROUTE_KEY=$(prop_upgrade_property_file ZEN_ROUTE_KEY)
    # ZEN_ROUTE_CA=$(prop_upgrade_property_file ZEN_ROUTE_CA)
    # ZEN_ROUTE_REENCRYPT=$(prop_upgrade_property_file ZEN_ROUTE_REENCRYPT)
    # ZEN_ROUTE_SECRET=$(prop_upgrade_property_file ZEN_ROUTE_SECRET)
    CS_OPERATOR_NAMESPACE=$(prop_upgrade_property_file CS_OPERATOR_NAMESPACE)
    CS_SERVICES_NAMESPACE=$(prop_upgrade_property_file CS_SERVICES_NAMESPACE)

    # ZEN_ROUTE_HOST=$(sed -e 's/^"//' -e 's/"$//' <<<"$ZEN_ROUTE_HOST")
    # ZEN_ROUTE_CERT=$(sed -e 's/^"//' -e 's/"$//' <<<"$ZEN_ROUTE_CERT")
    # ZEN_ROUTE_KEY=$(sed -e 's/^"//' -e 's/"$//' <<<"$ZEN_ROUTE_KEY")
    # ZEN_ROUTE_CA=$(sed -e 's/^"//' -e 's/"$//' <<<"$ZEN_ROUTE_CA")
    # ZEN_ROUTE_REENCRYPT=$(sed -e 's/^"//' -e 's/"$//' <<<"$ZEN_ROUTE_REENCRYPT")
    # ZEN_ROUTE_SECRET=$(sed -e 's/^"//' -e 's/"$//' <<<"$ZEN_ROUTE_SECRET")
    CS_OPERATOR_NAMESPACE=$(sed -e 's/^"//' -e 's/"$//' <<<"$CS_OPERATOR_NAMESPACE")
    CS_SERVICES_NAMESPACE=$(sed -e 's/^"//' -e 's/"$//' <<<"$CS_SERVICES_NAMESPACE")

    # ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_zen.zen_custom_route.route_host "\"$ZEN_ROUTE_HOST\""
    # ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_zen.zen_custom_route.route_cert "\"$ZEN_ROUTE_CERT\""
    # ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_zen.zen_custom_route.route_key "\"$ZEN_ROUTE_KEY\""
    # ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_zen.zen_custom_route.route_ca "\"$ZEN_ROUTE_CA\""
    # ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_zen.zen_custom_route.route_reencrypt "\"$ZEN_ROUTE_REENCRYPT\""
    # ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_zen.zen_custom_route.route_secret "\"$ZEN_ROUTE_SECRET\""
    ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_common_service.operator_namespace "\"$CS_OPERATOR_NAMESPACE\""
    ${YQ_CMD} w -i ${UPGRADE_CS_ZEN_FILE} spec.shared_configuration.sc_common_service.services_namespace "\"$CS_SERVICES_NAMESPACE\""

    # Retrieve existing Content CR
    content_cr_name=$(kubectl get content -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $content_cr_name ]; then
        info "Retrieving existing CP4BA Content (Kind: content.icp4a.ibm.com) Custom Resource"
        cr_type="content"
        cr_metaname=$(kubectl get content $content_cr_name -n $project_name -o yaml | ${YQ_CMD} r - metadata.name)
        owner_ref=$(kubectl get content $content_cr_name -n $project_name -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
        if [[ ${owner_ref} == "ICP4ACluster" ]]; then
            warning "Found one Content (Kind: content.icp4a.ibm.com) Custom Resource which is generated by CP4BA operator. The script will not change it."
            sleep 10
        else
            # # Check if the cp-console-iam-provider/cp-console-iam-idmgmt already created before upgrade Content deployment.
            # iam_idprovider=$(kubectl get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-provider)
            # iam_idmgmt=$(kubectl get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-idmgmt)
            # if [[ -z $iam_idprovider || -z $iam_idmgmt ]]; then
            #     fail "Not found route \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" under project \"$project_name\"."
            #     info "You have to create \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" before upgrade CP4BA deployment."
            #     exit 1
            # fi
            # if [[ ! -f $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP ]]; then
            kubectl get $cr_type $content_cr_name -n $project_name -o yaml > ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
            
            # Update the appVersion in foundationrequest
            foundationrequest_cr_name=$(kubectl get foundationrequest -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
            kubectl patch foundationrequest $foundationrequest_cr_name -n $project_name -p '{"spec":{"appVersion":"$CP4BA_RELEASE_BASE"}}' --type=merge >/dev/null 2>&1
            
            # Backup existing content CR
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}
            # fi

            info "Merging existing CP4BA Content Custom Resource with new version ($CP4BA_RELEASE_BASE)"
            # Delete unnecessary section in CR
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} status
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.annotations
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.creationTimestamp
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.generation
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.resourceVersion
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} metadata.uid

            # replace release/appVersion
            ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
            ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

            # Merge Zen YAML into content cr
            ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_CS_ZEN_FILE}

            ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}

            # Merge BAI save point into content cr
            bai_flag=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_TMP | ${YQ_CMD} r - spec.content_optional_components.bai`
            if [[ $bai_flag == "True" || $bai_flag == "true" ]]; then
                if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                    ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_BAI_TMP}
                fi
            fi
            # Disable sc_content_initialization/sc_content_verification
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_content_initialization "false"
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_content_verification "false"
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_content_initialization_update_scim

            # remove initialize_configuration/verify_configuration
            info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.verify_configuration
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.initialize_configuration
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.verify_configuration
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.initialize_configuration

            if [[ $cr_verison != "${CP4BA_RELEASE_BASE}" ]]; then
                # Set sc_restricted_internet_access always "false" in upgrade
                info "${RED_TEXT}Setting \"sc_egress_configuration.sc_restricted_internet_access\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements of security.${RESET_TEXT}"
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "false"

                # Set shared_configuration.enable_fips always "false" in upgrade
                info "${RED_TEXT}Setting \"shared_configuration.enable_fips\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements.${RESET_TEXT}"
                ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.shared_configuration.enable_fips "false"
            fi
            # Set host_federated_portal as false in upgrade if it exist
            flag_host=`cat ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} | ${YQ_CMD} r - spec.baw_configuration.[0].host_federated_portal`
            if [[ ! -z $flag_host ]]; then
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.baw_configuration.[0].host_federated_portal  "false"
            fi

            flag_host=`cat ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} | ${YQ_CMD} r - spec.baw_configuration.[1].host_federated_portal`
            if [[ ! -z $flag_host ]]; then
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} spec.baw_configuration.[1].host_federated_portal  "false"
            fi

            ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
            ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
            ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
            
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR}

            # Disable CSS indexing
            # scale down FNCM Deployment
            info "Scaling down CSS deployment"
            css_instance_number=0
            css_instance_index=1
            while true; do
                kubectl get deployment ${cr_metaname}-css-deploy-${css_instance_index} >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    break
                else
                    ((css_instance_index++))
                    ((css_instance_number++))
                fi

            done
            if (( $css_instance_number > 0  )); then
                for ((j=1;j<=${css_instance_number};j++));
                do
                    kubectl scale --replicas=0 deployment ${cr_metaname}-css-deploy-${j} -n $project_name >/dev/null 2>&1
                done
            fi

            info "Scaling down CPE deployment"
            kubectl scale --replicas=0 deployment ${cr_metaname}-cpe-deploy -n $project_name >/dev/null 2>&1
            echo "Done!"
            info "Scaling down Navigator deployment"
            kubectl scale --replicas=0 deployment ${cr_metaname}-navigator-deploy -n $project_name >/dev/null 2>&1
            echo "Done!"

            # info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
            # kubectl patch content $content_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
            # kubectl patch content $content_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

            info "Scaling up \"IBM CP4BA FileNet Content Manager\" operator"
            kubectl scale --replicas=1 deployment ibm-content-operator -n $project_name >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                sleep 1
                echo "Done!"
            else
                fail "Failed to scale up \"IBM CP4BA FileNet Content Manager\" operator"
            fi

            info "Scaling up \"IBM CP4BA Foundation\" operator to install zenService"
            kubectl scale --replicas=1 deployment icp4a-foundation-operator -n $project_name >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                sleep 1
                echo "Done!"
            else
                fail "Failed to scale up \"IBM CP4BA Foundation\" operator"
            fi

            info "Scaling up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator to install zenService"
            kubectl scale --replicas=1 deployment ibm-cp4a-operator -n $project_name >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                sleep 1
                echo "Done!"
            else
                fail "Failed to scale up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
            fi

            info "The new version ($CP4BA_RELEASE_BASE) of CP4BA Content Custom Resource is created ${UPGRADE_DEPLOYMENT_CONTENT_CR}"

            ## remove all image tags
            ${SED_COMMAND} "/tag: .*/d" ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_CONTENT_CR_TMP} ${UPGRADE_DEPLOYMENT_CONTENT_CR}
            info "IMAGE TAGS ARE REMOVED FROM THE NEW VERSION OF THE CUSTOM RESOURCE \"${UPGRADE_DEPLOYMENT_CONTENT_CR}\"."
            printf "\n"

            select_apply_cr
            
            if [[ $APPLY_UPDATED_CR == "Yes" ]]; then
                info "Remove initialize_configuration/verify_configuration from CP4BA Content Custom Resource"
                kubectl patch content $content_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
                kubectl patch content $content_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

                info "Applying the custom resource ${UPGRADE_DEPLOYMENT_CONTENT_CR}"
                kubectl annotate content $content_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $project_name >/dev/null 2>&1
                kubectl apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $project_name >/dev/null 2>&1

                if [ $? -ne 0 ]; then
                    fail "Failed to update IBM CP4BA Content Custom Resource."
                else
                    echo "Done!"
                    printf "\n"
                fi

                echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
                echo "${YELLOW_TEXT}How to check the overall upgrade status for CP4BA/zenService/IM${RESET_TEXT}"
                echo "STEP1: ${RED_TEXT}# ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
            else
                printf "\n"
                echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
                echo "${YELLOW_TEXT}After review or configure and customize the parameters, you can apply custom resource follow below command manually.${RESET_TEXT}"
                echo "STEP1:${RED_TEXT} # kubectl patch content $content_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]'${RESET_TEXT}"
                echo "STEP2:${RED_TEXT} # kubectl patch content $content_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]'${RESET_TEXT}"
                echo "STEP3:${RED_TEXT} # kubectl annotate content $content_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $project_name${RESET_TEXT}"
                echo "STEP4:${RED_TEXT} # kubectl apply -f ${UPGRADE_DEPLOYMENT_CONTENT_CR} -n $project_name${RESET_TEXT}"
                echo "${YELLOW_TEXT}How to check the overall upgrade status for CP4BA/zenService/IM${RESET_TEXT}"
                echo "STEP5: ${RED_TEXT}# ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
            fi
            printf "\n"
            echo "${YELLOW_TEXT}[ATTENTION]: The zenService will be ready in about 30 minutes after the new version ($CP4BA_RELEASE_BASE) of CP4BA custom resource was applied.${RESET_TEXT}"

            # if [ $? -ne 0 ]; then
            #     fail "IBM Cloud Pak® for Business Automation Content custom resource update failed"
            #     exit 1
            # else
            #     echo "Done!"

            #     printf "\n"
            #     # echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}: "
            #     # msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $project_name\" to get overview upgrade status for CP4BA"
            # fi
        fi
    fi

    # Retrieve existing WfPSRuntime CR
    exist_wfps_cr_array=($(kubectl get WfPSRuntime -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            info "Retrieving existing IBM CP4BA Workflow Process Service (Kind: WfPSRuntime.icp4a.ibm.com) Custom Resource: \"${item}\""
            cr_type="WfPSRuntime"
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name -o yaml | ${YQ_CMD} r - metadata.name)
            UPGRADE_DEPLOYMENT_WFPS_CR=${UPGRADE_DEPLOYMENT_CR}/wfps_${cr_metaname}.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_TMP=${UPGRADE_DEPLOYMENT_CR}/.wfps_${cr_metaname}_tmp.yaml
            UPGRADE_DEPLOYMENT_WFPS_CR_BAK=${UPGRADE_DEPLOYMENT_CR_BAK}/wfps_cr_${cr_metaname}_backup.yaml

            kubectl get $cr_type ${item} -n $project_name -o yaml > ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            
            # Backup existing WfPSRuntime CR
            mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR_BAK}

            info "Merging existing IBM CP4BA Workflow Process Service custom resource: \"${item}\" with new version ($CP4BA_RELEASE_BASE)"
            # Delete unnecessary section in CR
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} status
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.annotations
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.creationTimestamp
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.generation
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.resourceVersion
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} metadata.uid

            # replace release/appVersion
            # ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_PFS_CR_TMP}
            ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}

            # # change failureThreshold/periodSeconds for WfPS before upgrade
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.failureThreshold 800
            # ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} spec.node.probe.startupProbe.periodSeconds 10

            ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP}
            
            ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_WFPS_CR_TMP} ${UPGRADE_DEPLOYMENT_WFPS_CR}
            success "Completed to merge existing IBM CP4BA Workflow Process Service custom resource with new version ($CP4BA_RELEASE_BASE)"

            info "Scaling up \"IBM CP4BA Workflow Process Service\" operator"
            kubectl scale --replicas=1 deployment ibm-cp4a-wfps-operator -n $project_name >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                sleep 1
                echo "Done!"
            else
                fail "Failed to scale up \"IBM CP4BA Workflow Process Service\" operator"
            fi

            # Check IBM CP4BA Workflow Process Service operator upgrade status
            echo "****************************************************************************"
            info "Checking for IBM CP4BA Workflow Process Service operator pod initialization"
            maxRetry=10
            for ((retry=0;retry<=${maxRetry};retry++)); do
                isReady=$(kubectl get csv ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION -n $project_name -o jsonpath='{.status.phase}')
                # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine $CP4BA_RELEASE_BASE")
                if [[ $isReady != "Succeeded" ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    warning "Timeout Waiting for IBM CP4BA Workflow Process Service operator to start"
                    echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                    echo "oc describe pod $(oc get pod -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
                    echo "oc describe rs $(oc get rs -n $project_name|grep ibm-cp4a-wfps-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    exit 1
                    else
                    sleep 30
                    echo -n "..."
                    continue
                    fi
                elif [[ $isReady == "Succeeded" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-cp4a-wfps-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM CP4BA Workflow Process Service operator pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM CP4BA Workflow Process Service operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                fi
            done
            echo "****************************************************************************"


            info "Apply the new version ($CP4BA_RELEASE_BASE) of IBM CP4BA Workflow Process Service custom resource"
            kubectl annotate WfPSRuntime ${item} kubectl.kubernetes.io/last-applied-configuration- -n $project_name >/dev/null 2>&1
            kubectl apply -f ${UPGRADE_DEPLOYMENT_WFPS_CR} -n $project_name >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                fail "IBM CP4BA Workflow Process Service custom resource update failed"
                exit 1
            else
                echo "Done!"

                printf "\n"
                # echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
                # msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $project_name\" to get overview upgrade status for IBM CP4BA Workflow Process Service"
            fi
        done
    fi

    # Retrieve existing ICP4ACluster CR
    icp4acluster_cr_name=$(kubectl get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z $icp4acluster_cr_name ]; then
        info "Retrieving existing CP4BA ICP4ACluster (Kind: icp4acluster.icp4a.ibm.com) Custom Resource"
        cr_type="icp4acluster"
        cr_metaname=$(kubectl get icp4acluster $icp4acluster_cr_name -n $project_name -o yaml | ${YQ_CMD} r - metadata.name)

        kubectl get $cr_type $icp4acluster_cr_name -n $project_name -o yaml > ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        existing_pattern_list=""
        existing_opt_component_list=""
        
        EXISTING_PATTERN_ARR=()
        EXISTING_OPT_COMPONENT_ARR=()
        existing_pattern_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
        existing_opt_component_list=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

        OIFS=$IFS
        IFS=',' read -r -a EXISTING_PATTERN_ARR <<< "$existing_pattern_list"
        IFS=',' read -r -a EXISTING_OPT_COMPONENT_ARR <<< "$existing_opt_component_list"
        IFS=$OIFS

        # # Check if the cp-console-iam-provider/cp-console-iam-idmgmt already created before upgrade CP4BA deployment.  
        # if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
        #     iam_idprovider=$(kubectl get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-provider)
        #     iam_idmgmt=$(kubectl get route -n $project_name -o 'custom-columns=NAME:.metadata.name' --no-headers --ignore-not-found | grep cp-console-iam-idmgmt)
        #     if [[ -z $iam_idprovider || -z $iam_idmgmt ]]; then
        #         fail "Not found route \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" under project \"$project_name\"."
        #         info "You have to create \"cp-console-iam-idmgmt\" and \"cp-console-iam-provider\" before upgrade CP4BA deployment."
        #         exit 1
        #     fi
        # fi

        # Backup existing icp4acluster CR
        mkdir -p ${UPGRADE_DEPLOYMENT_CR_BAK}
        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}
        # fi
        info "Merging existing CP4BA Custom Resource with new version ($CP4BA_RELEASE_BASE)"
        # Delete unnecessary section in CR
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} status
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.annotations
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.creationTimestamp
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.generation
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.resourceVersion
        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} metadata.uid

        # replace release/appVersion
        ${SED_COMMAND} "s|release: .*|release: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s|appVersion: .*|appVersion: ${CP4BA_RELEASE_BASE}|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        
        # Add "kafka" into sc_optional_component if kafka_services.enable is true when upgrade
        if [[ ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring")) ]]; then
            kafka_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.kafka_services`
            if [[ $kafka_flag == "True" || $kafka_flag == "true" ]]; then
                EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "kafka" )
            fi
        fi
        
        # make PFS as an optional component for BAW and WfPS Authoring
        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
            if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
                if [[ ! (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
                    EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "pfs" )
                fi
            fi
            # Workflow authoring/WfPS authoring use embedded PFS starting from $CP4BA_RELEASE_BASE
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.pfs_configuration
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[0].pfs_bpd_database_init_job
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.pfs_bpd_database_init_job
            # DBACLD-113568
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.kafka_services
            
            kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
            kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/0/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
            kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/kafka_services"}]' >/dev/null 2>&1
        fi

       # Convert optional components array to list by common
        delim=""
        opt_components_joined=""
        for item in "${EXISTING_OPT_COMPONENT_ARR[@]}"; do
            opt_components_joined="$opt_components_joined$delim$item"
            delim=","
        done


        # Set sc_optional_components='' when none optional component selected
        if [ "${#EXISTING_OPT_COMPONENT_ARR[@]}" -eq "0" ]; then
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        else
            ${SED_COMMAND} "s|sc_optional_components:.*|sc_optional_components: \"$opt_components_joined\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        fi

        # Change ssl_protocol for PFS required in $CP4BA_RELEASE_BASE release
        pfs_ssl_protocol=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.pfs_configuration.security.ssl_protocol`
        if [ ! -z "$pfs_ssl_protocol" ]; then
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.pfs_configuration.security.ssl_protocol "TLSv1.2"
        fi
        # Merge Zen YAML into icp4acluster cr
        ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_CS_ZEN_FILE}

        # Merge BAI save point into content cr
        if [[ (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "bai") ]]; then
            if [ -s ${UPGRADE_DEPLOYMENT_BAI_TMP} ]; then
                ${YQ_CMD} m -i -a -M --overwrite ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_BAI_TMP}
            fi
        fi

        ${SED_COMMAND} "s/route_reencrypt: .*/route_reencrypt: $ZEN_ROUTE_REENCRYPT/g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        # for BAW authoring, base on initialize_configuration to set workflow_authoring_configuration.case.datasource_name_tos/connection_point_name_tos
        if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
            baw_datasource_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.datasource_name_tos`
            baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.connection_point_name_tos`
            if [[ -z "$baw_datasource_name_tos" || -z "$baw_connection_point_name_tos" ]]; then
                init_section=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration`
                if [[ -z "$init_section" ]]; then
                    info "Not found initialize_configuration, continue..."
                    # For upgrade to 23.0.1 olny, remove it in 23.0.2 release
                    # info "If you want to add workflow_authoring_configuration.case.datasource_name_tos/connection_point_name_tos manually following https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=upgrade-upgrading-business-automation-workflow-authoring"
                else
                    os_index=0
                    while true; do
                        os_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name`
                        if [[ ! -z "$os_flag" ]]; then
                            enable_workflow=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow`
                            if [[ "$enable_workflow" == "true" ]]; then
                                tos_datasource_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name`
                                tos_connection=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name`
                                if [[ ! -z "$tos_datasource_name" ]]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.datasource_name_tos "$tos_datasource_name"
                                fi
                                if [[ ! -z "$tos_connection" ]]; then
                                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.connection_point_name_tos "$tos_connection"
                                fi
                            fi
                            ((os_index++))
                        else
                            break
                        fi
                    done
                fi
            fi
        fi

        # for BAW authoring, set workflow_authoring_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        if [[ " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
            baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case`
            if [[ ! -z "$baw_instance_flag" ]]; then
                baw_object_store_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.object_store_name_tos`
                baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.connection_point_name_tos`
                baw_target_environment_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.target_environment_name`
                baw_desktop_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.workflow_authoring_configuration.case.desktop_name`
                
                if [[ (-z $baw_connection_point_name_tos || -z $baw_object_store_name_tos) && (-z $init_section) ]]; then    
                    warning "Not found both workflow_authoring_configuration.case.connection_point_name_tos/object_store_name_tos and oc_cpe_obj_store_workflow_pe_conn_point_name under initialize_configuration, please refer KC https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-business-automation-workflow-authoring"
                fi
                if [[ ! -z "$baw_object_store_name_tos" ]]; then
                    ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].object_store_name "$baw_object_store_name_tos"

                    if [[ ! -z $baw_connection_point_name_tos ]]; then
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].connection_point_name "$baw_connection_point_name_tos"
                    fi

                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.object_store_name_tos
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.connection_point_name_tos
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.datasource_name_tos

                    if [[ -z $baw_target_environment_name ]]; then
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].target_environment_name "dev_env_connection_definition"
                    else
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].target_environment_name "$baw_target_environment_name"
                    fi
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.target_environment_name
                    
                    if [[ -z $baw_desktop_name ]]; then
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].desktop_id "baw"
                    else
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.tos_list.[0].desktop_id "$baw_desktop_name"
                    fi
                    ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.workflow_authoring_configuration.case.desktop_name
                fi
                # Delete datasource_name_tos/object_store_name_tos and so on from existing CR
                kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/object_store_name_tos"}]' >/dev/null 2>&1
                kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/connection_point_name_tos"}]' >/dev/null 2>&1
                kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/datasource_name_tos"}]' >/dev/null 2>&1
                kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/target_environment_name"}]' >/dev/null 2>&1
                kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/case/desktop_name"}]' >/dev/null 2>&1
            fi
        fi

        # for BAW runtime, base on initialize_configuration set baw_configuration[0].case.datasource_name_tos/connection_point_name_tos
        if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" ]]; then
            baw_instance_index=0
            while true; do
                baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    baw_datasource_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos`
                    baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos`
                    if [[ -z "$baw_datasource_name_tos" || -z "$baw_connection_point_name_tos" ]]; then
                        init_section=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration`
                        if [[ -z "$init_section" ]]; then
                            info "Not found initialize_configuration, continue..."
                            # For upgrade to 23.0.1 olny, remove it in 23.0.2 release
                            # info "If you want to add baw_configuration.[0].case.datasource_name_tos/connection_point_name_tos manually following https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=upgrade-upgrading-business-automation-workflow-authoring"
                        else
                            os_index=0
                            while true; do
                                os_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_symb_name`
                                if [[ ! -z "$os_flag" ]]; then
                                    enable_workflow=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_enable_workflow`
                                    if [[ "$enable_workflow" == "true" ]]; then
                                        tos_datasource_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_conn.dc_os_datasource_name`
                                        tos_connection=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.initialize_configuration.ic_obj_store_creation.object_stores.[${os_index}].oc_cpe_obj_store_workflow_pe_conn_point_name`
                                        if [[ ! -z "$tos_datasource_name" ]]; then
                                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos "$tos_datasource_name"
                                        fi
                                        if [[ ! -z "$tos_connection" ]]; then
                                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos "$tos_connection"
                                        fi
                                    fi
                                    ((os_index++))
                                else
                                    break
                                fi
                            done
                        fi
                    fi
                    ((baw_instance_index++))
                else
                    break
                fi
            done
        fi

        # for BAW Runtime, set baw_configuration.case.tos_list
        # Support multiple tos instance from $CP4BA_RELEASE_BASE
        if [[ (! " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" ]]; then
            # Support multiple tos instance from $CP4BA_RELEASE_BASE
            baw_instance_index=0
            while true; do
                baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    baw_object_store_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos`
                    baw_connection_point_name_tos=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos`
                    baw_target_environment_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.target_environment_name`
                    baw_desktop_name=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case.desktop_name`
                    if [[ (-z $baw_connection_point_name_tos || -z $baw_object_store_name_tos) && (-z $init_section) ]]; then    
                        warning "Not found both baw_configuration.[0].case.connection_point_name_tos/object_store_name_tos and oc_cpe_obj_store_workflow_pe_conn_point_name under initialize_configuration, please refer KC https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE?topic=deployment-upgrading-business-automation-workflow-runtime"
                    fi
                    if [[ ! -z "$baw_object_store_name_tos" ]]; then
                        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].object_store_name "$baw_object_store_name_tos"
                        
                        if [[ ! -z $baw_connection_point_name_tos ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].connection_point_name "$baw_connection_point_name_tos"
                        fi

                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.object_store_name_tos
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.connection_point_name_tos
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.datasource_name_tos

                        if [[ -z $baw_target_environment_name ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].target_environment_name "target_env"
                        else
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].target_environment_name "$baw_target_environment_name"
                        fi
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.target_environment_name
                        
                        if [[ -z $baw_desktop_name ]]; then
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].desktop_id "baw"
                        else
                            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.tos_list.[0].desktop_id "$baw_desktop_name"
                        fi
                        ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[${baw_instance_index}].case.desktop_name
                    fi
                    ((baw_instance_index++))
                else
                    break
                fi
            done
            # Delete datasource_name_tos/object_store_name_tos and so on from existing CR
            baw_instance_index=0
            while true; do
                baw_instance_flag=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP | ${YQ_CMD} r - spec.baw_configuration.[${baw_instance_index}].case`
                if [[ ! -z "$baw_instance_flag" ]]; then
                    kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/${baw_instance_index}/case/object_store_name_tos"}]' >/dev/null 2>&1
                    kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/${baw_instance_index}/case/connection_point_name_tos"}]' >/dev/null 2>&1
                    kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/${baw_instance_index}/case/datasource_name_tos"}]' >/dev/null 2>&1
                    kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/${baw_instance_index}/case/target_environment_name"}]' >/dev/null 2>&1
                    kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/${baw_instance_index}/case/desktop_name"}]' >/dev/null 2>&1
                    ((baw_instance_index++))
                else
                    break
                fi
            done
        fi

        if [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "content") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") || (" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring") || (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "ae_data_persistence") ]]; then
            # Disable sc_content_initialization/sc_content_verification
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_content_initialization "false"
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_content_verification "false"
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_content_initialization_update_scim

            # remove initialize_configuration/verify_configuration
            info "Remove initialize_configuration/verify_configuration from CP4BA Custom Resource"
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.verify_configuration
            ${YQ_CMD} d -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.initialize_configuration
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.verify_configuration
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.initialize_configuration

            # Disable CSS indexing
            # scale down FNCM Deployment
            info "Scaling down CSS deployment"
            css_instance_number=0
            css_instance_index=1
            while true; do
                kubectl get deployment ${cr_metaname}-css-deploy-${css_instance_index} >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    break
                else
                    ((css_instance_index++))
                    ((css_instance_number++))
                fi
            done
            if (( $css_instance_number > 0  )); then
                for ((j=1;j<=${css_instance_number};j++));
                do
                    kubectl scale --replicas=0 deployment ${cr_metaname}-css-deploy-${j} -n $project_name >/dev/null 2>&1
                done
            fi
            echo "Done!"
            info "Scaling down CPE deployment"
            kubectl scale --replicas=0 deployment ${cr_metaname}-cpe-deploy -n $project_name >/dev/null 2>&1
            echo "Done!"
            info "Scaling down Navigator deployment"
            kubectl scale --replicas=0 deployment ${cr_metaname}-navigator-deploy -n $project_name >/dev/null 2>&1
            echo "Done!"
        fi

        if [[ $cr_verison != "${CP4BA_RELEASE_BASE}" ]]; then
            # Set sc_restricted_internet_access always "false" in upgrade
            info "${RED_TEXT}Setting \"sc_egress_configuration.sc_restricted_internet_access\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements of security.${RESET_TEXT}"
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "false"
            # Set shared_configuration.enable_fips always "false" in upgrade
            info "${RED_TEXT}Setting \"shared_configuration.enable_fips\" as \"false\" when upgrade CP4BA deployment, you could change it according to your requirements.${RESET_TEXT}"
            ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.shared_configuration.enable_fips "false"
        fi
        # Set host_federated_portal as false in upgrade if it exist
        flag_host=`cat ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} | ${YQ_CMD} r - spec.baw_configuration.[0].host_federated_portal`
        if [[ ! -z $flag_host ]]; then
        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[0].host_federated_portal  "false"
        fi

        flag_host=`cat ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} | ${YQ_CMD} r - spec.baw_configuration.[1].host_federated_portal`
        if [[ ! -z $flag_host ]]; then
        ${YQ_CMD} w -i ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} spec.baw_configuration.[1].host_federated_portal  "false"
        fi

        ${SED_COMMAND} "s|'\"|\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${SED_COMMAND} "s|\"'|\"|g" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}

        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}
        success "Completed to merge existing CP4BA Custom Resource with new version ($CP4BA_RELEASE_BASE)"
        # info "Remove initialize_configuration/verify_configuration from CP4BA Custom Resource"
        # kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
        # kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

        # if [[ ((" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") && (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "baw_authoring")) || (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-process-service") ]]; then
        info "Remove pfs_configuration/pfs_bpd_database_init_job/elasticsearch_configuration from CP4BA Custom Resource"
        # if [[ ! (" ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "pfs") ]]; then
        #     EXISTING_OPT_COMPONENT_ARR=( "${EXISTING_OPT_COMPONENT_ARR[@]}" "pfs" )
        # fi
        # Workflow authoring/runtime and WfPS authoring use embedded PFS starting from $CP4BA_RELEASE_BASE
        kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/pfs_configuration"}]' >/dev/null 2>&1
        kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/elasticsearch_configuration"}]' >/dev/null 2>&1
        kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/baw_configuration/0/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
        kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/workflow_authoring_configuration/pfs_bpd_database_init_job"}]' >/dev/null 2>&1
        # fi

        info "Scaling up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator to install zenService"
        kubectl scale --replicas=1 deployment ibm-cp4a-operator -n $project_name >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            sleep 1
            echo "Done!"
        else
            fail "Failed to scale up \"IBM Cloud Pak for Business Automation (CP4BA) multi-pattern\" operator"
        fi

        info "The new version ($CP4BA_RELEASE_BASE) of CP4BA Custom Resource is created ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}"

        ## remove all image tags
        ${SED_COMMAND} "/tag: .*/d" ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP}
        ${COPY_CMD} -rf ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_TMP} ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}
        info "IMAGE TAGS ARE REMOVED FROM THE NEW VERSION OF THE CUSTOM RESOURCE \"${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}\"."
        printf "\n"

        select_apply_cr

        if [[ $APPLY_UPDATED_CR == "Yes" ]]; then
            info "Remove initialize_configuration/verify_configuration from CP4BA Custom Resource"
            kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]' >/dev/null 2>&1
            kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]' >/dev/null 2>&1

            info "Applying the custom resource ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR}"
            kubectl annotate icp4acluster $icp4acluster_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $project_name >/dev/null 2>&1
            kubectl apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $project_name >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                fail "Failed to update IBM CP4BA Custom Resource."
            else
                echo "Done!"
                printf "\n"
            fi

            echo "${YELLOW_TEXT}[NEXT ACTION]:${RESET_TEXT}"
            echo "${YELLOW_TEXT}How to check the overall upgrade status for CP4BA/zenService/IM${RESET_TEXT}"
            echo "STEP1:${RED_TEXT} # ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
        else
            printf "\n"
            echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}:"
            echo "${YELLOW_TEXT}After review or configure and customize the parameters, you can apply custom resource follow below command manually.${RESET_TEXT}"
            echo "STEP1:${RED_TEXT} # kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/initialize_configuration"}]'${RESET_TEXT}"
            echo "STEP2:${RED_TEXT} # kubectl patch icp4acluster $icp4acluster_cr_name -n $project_name --type=json -p='[{"op": "remove", "path": "/spec/verify_configuration"}]'${RESET_TEXT}"
            echo "STEP3:${RED_TEXT} # kubectl annotate icp4acluster $icp4acluster_cr_name kubectl.kubernetes.io/last-applied-configuration- -n $project_name${RESET_TEXT}"
            echo "STEP4:${RED_TEXT} # kubectl apply -f ${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR} -n $project_name${RESET_TEXT}"
            echo "${YELLOW_TEXT}How to check the overall upgrade status for CP4BA/zenService/IM${RESET_TEXT}"
            echo "STEP5:${RED_TEXT} # ./cp4a-deployment.sh -m upgradeDeploymentStatus -n $TARGET_PROJECT_NAME${RESET_TEXT}"
        fi
        
        printf "\n"
        echo "${YELLOW_TEXT}[ATTENTION]: The zenService will be ready in about 30 minutes after the new version ($CP4BA_RELEASE_BASE) of CP4BA custom resource was applied.${RESET_TEXT}"
        printf "\n"

        # if [ $? -ne 0 ]; then
        #     fail "IBM Cloud Pak® for Business Automation custom resource update failed"
        #     exit 1
        # else
        #     echo "Done!"

        #     printf "\n"
        #     # echo "${YELLOW_TEXT}[NEXT ACTION]${RESET_TEXT}: "
        #     # msgB "Run \"cp4a-deployment.sh -m upgradeDeploymentStatus -n $project_name\" to get overview upgrade status for CP4BA"
        # fi
    fi

    if [[ (-z $icp4acluster_cr_name) && (-z $content_cr_name) && (-z $exist_wfps_cr_array) ]]; then
        fail "No found Content or ICP4ACluster or WfPSRuntime custom resource in project \"$project_name\""
        exit 1
    fi
}
