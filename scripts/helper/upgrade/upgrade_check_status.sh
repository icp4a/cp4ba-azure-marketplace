#!/BIN/BASH
# set -x
###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2023. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

# function for checking operator version
function check_cp4ba_operator_version(){
    local project_name=$1
    local maxRetry=5
    info "Checking the version of IBM Cloud Pak® for Business Automation Operator"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cp4a_operator_csv_name=$(kubectl get csv -n $project_name --no-headers --ignore-not-found | grep "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern" | awk '{print $1}')
        cp4a_operator_csv_version=$(kubectl get csv $cp4a_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ "$cp4a_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            success "The current IBM Cloud Pak® for Business Automation Operator is already ${CP4BA_CSV_VERSION//v/}"
            break
            # exit 1
        elif [[ "$cp4a_operator_csv_version" == "22.2."* || "$cp4a_operator_csv_version" == "23.1."* || "$cp4a_operator_csv_version" == "23.2."* ]]; then
            cp4a_operator_csv=$(kubectl get csv $cp4a_operator_csv_name -n $project_name -o 'jsonpath={.spec.version}')
            # cp4a_operator_csv="22.2.2"
            requiredver="22.2.2"
            if [ ! "$(printf '%s\n' "$requiredver" "$cp4a_operator_csv" | sort -V | head -n1)" = "$requiredver" ]; then
                fail "Please upgrade to CP4BA 22.0.2-IF002 or later iFix before you can upgrade to CP4BA 23.0.1 GA"
                exit 1
            else
                info "Found IBM Cloud Pak® for Business Automation Operator is \"$cp4a_operator_csv_version\" version."
                break
            fi
        elif [[ "$cp4a_operator_csv_version" != "${CP4BA_CSV_VERSION//v/}" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                info "Timeout Checking for the version of IBM Cloud Pak® for Business Automation under project \"$project_name\""
                exit 1
            else
                sleep 2
                echo -n "..."
                continue
            fi
        fi
    done
    # success "Found the IBM Cloud Pak® for Business Automation Operator $cp4a_operator_csv_version \n"
}

# function for checking operator version
function check_content_operator_version(){
    local project_name=$1
    local maxRetry=5
    info "Checking the version of IBM CP4BA FileNet Content Manager Operator"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        cp4a_content_operator_csv_name=$(kubectl get csv -n $project_name --no-headers --ignore-not-found | grep "IBM CP4BA FileNet Content Manager" | awk '{print $1}')
        cp4a_content_operator_csv_version=$(kubectl get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')

        if [[ "$cp4a_content_operator_csv_version" == "${CP4BA_CSV_VERSION//v/}" ]]; then
            success "The current IBM CP4BA FileNet Content Manager Operator is already ${CP4BA_CSV_VERSION//v/}"
            break
        elif [[ "$cp4a_content_operator_csv_version" == "22.2."* || "$cp4a_content_operator_csv_version" == "23.1."* || "$cp4a_content_operator_csv_version" == "23.2."* ]]; then
            cp4a_content_operator_csv=$(kubectl get csv $cp4a_content_operator_csv_name -n $project_name --no-headers --ignore-not-found -o 'jsonpath={.spec.version}')
            # cp4a_operator_csv="22.2.2"
            requiredver="22.2.2"
            if [ ! "$(printf '%s\n' "$requiredver" "$cp4a_content_operator_csv" | sort -V | head -n1)" = "$requiredver" ]; then
                fail "Please upgrade to CP4BA 22.0.2-IF002 or later iFix before you can upgrade to CP4BA 23.0.1 GA"
                exit 1
            else
                info "Found IBM CP4BA FileNet Content Manager Operator is \"$cp4a_content_operator_csv_version\" version."
                break
            fi
        elif [[ "$cp4a_content_operator_csv_version" != "${CP4BA_CSV_VERSION//v/}" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                info "Timeout Checking for the version of IBM CP4BA FileNet Content Manager Operator under project \"$project_name\""
                exit 1
            else
                sleep 2
                echo -n "..."
                continue
            fi
        fi
    done
    # success "Found the IBM CP4BA FileNet Content Manager Operator $cp4a_content_operator_csv_version \n"
}

function check_operator_status(){
    local maxRetry=30
    local project_name=$1
    local check_mode=$2 # full or part
    local check_channel=$3
    CHECK_CP4BA_OPERATOR_RESULT=()

    # Check Common Service Operator 4.0
    if [[ "$check_mode" == "full" ]]; then
        local maxRetry=10
        echo "****************************************************************************"
        info "Checking for IBM Cloud Pak foundational operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(kubectl get csv ibm-common-service-operator.$CS_OPERATOR_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout Waiting for IBM Cloud Pak foundational operator to start"
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-common-service-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-common-service-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM Cloud Pak foundational Operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM Cloud Pak foundational Operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi


    # Check CP4BA operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        local maxRetry=20
        echo "****************************************************************************"
        info "Checking for IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(kubectl get csv ibm-cp4a-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                fail "Failed to upgrade the IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator to ibm-cp4a-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                exit 1
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout Waiting for IBM Cloud Pak for Business Automation (CP4BA) multi-pattern operator to start"
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
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-cp4a-operator,release=23.0.1 -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                elif [[ "$check_channel" == "channel" ]]; then
                    success "IBM Cloud Pak for Business Automation (CP4BA) multi-pattern Operator is in the phase of \"$isReady\"!"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # Check IBM CP4BA FileNet Content Manager operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA FileNet Content Manager operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(kubectl get csv ibm-content-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-content-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA FileNet Content Manager operator to ibm-content-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout Waiting for IBM CP4BA FileNet Content Manager operator to start"
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
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-content-operator,release=$CP4BA_RELEASE_BASE --no-headers --ignore-not-found -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA FileNet Content Manager operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA FileNet Content Manager operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA FileNet Content Manager operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"

    # Check CP4BA Foundation operator upgrade status
    echo "****************************************************************************"
    info "Checking for CP4BA Foundation operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(kubectl get csv icp4a-foundation-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep icp4a-foundation-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Foundation operator to icp4a-foundation-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout Waiting for CP4BA Foundation operator to start"
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep icp4a-foundation-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=icp4a-foundation-operator,release=$CP4BA_RELEASE_BASE --no-headers --ignore-not-found -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Foundation operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Foundation operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Foundation operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"

    # Check IBM CP4BA Automation Decision Service operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Automation Decision Service operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(kubectl get csv ibm-ads-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-ads-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Automation Decision Service operator to ibm-ads-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout Waiting for IBM CP4BA Automation Decision Service operator to start"
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep ibm-ads-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-ads-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Automation Decision Service operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Automation Decision Service operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Automation Decision Service operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"


    # Check IBM Operational Decision Manager operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        echo "****************************************************************************"
        info "Checking for IBM Operational Decision Manager operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(kubectl get csv ibm-odm-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                csv_version=""
                csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-odm-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        fail "Failed to upgrade the IBM Operational Decision Manager operator to ibm-odm-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                        msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                        exit 1
                    else
                        sleep 30
                        echo -n "..."
                        continue
                    fi
                fi
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout Waiting for IBM Operational Decision Manager operator to start"
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-odm-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-odm-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM Operational Decision Manager pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM Operational Decision Manager operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                elif [[ "$check_channel" == "channel" ]]; then
                    success "IBM Operational Decision Manager operator is in the phase of \"$isReady\"!"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # Check IBM Document Processing Engine operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        # Check the target cluster arch type

        arch_type=$(kubectl get cm cluster-config-v1 -n kube-system --no-headers --ignore-not-found -o yaml | grep -i architecture|tail -1| awk '{print $2}')
        if [[ "$arch_type" == "amd64" ]]; then
            echo "****************************************************************************"
            info "Checking for IBM Document Processing Engine operator pod initialization"
            for ((retry=0;retry<=${maxRetry};retry++)); do
                isReady=$(kubectl get csv ibm-dpe-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
                # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
                if [[ -z $isReady ]]; then
                    csv_version=""
                    csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-dpe-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                    if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                        if [[ $retry -eq ${maxRetry} ]]; then
                            fail "Failed to upgrade the IBM Document Processing Engine operator to ibm-dpe-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                            msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                            exit 1
                        else
                            sleep 30
                            echo -n "..."
                            continue
                        fi
                    fi
                elif [[ $isReady != "Succeeded" ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                    printf "\n"
                    warning "Timeout Waiting for IBM Document Processing Engine operator to start"
                    echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                    echo "oc describe pod $(oc get pod -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
                    echo "oc describe rs $(oc get rs -n $project_name|grep ibm-dpe-operator|awk '{print $1}') -n $project_name"
                    printf "\n"
                    exit 1
                    else
                    sleep 30
                    echo -n "..."
                    continue
                    fi
                elif [[ $isReady == "Succeeded" ]]; then
                    if [[ "$check_channel" != "channel" ]]; then
                        pod_name=$(kubectl get pod -l=name=ibm-dpe-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                        if [ -z $pod_name ]; then
                            error "IBM Document Processing Engine pod is NOT running"
                            CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                            break
                        else
                            success "IBM Document Processing Engine operator is running"
                            info "Pod: $pod_name"
                            CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                            break
                        fi
                    elif [[ "$check_channel" == "channel" ]]; then
                        success "IBM Document Processing Engine operator is in the phase of \"$isReady\"!"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                fi
            done
            echo "****************************************************************************"
        fi
    fi

    # Check IBM CP4BA Workflow Process Service operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Workflow Process Service operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(kubectl get csv ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-cp4a-wfps-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Workflow Process Service operator to ibm-cp4a-wfps-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        elif [[ $isReady != "Succeeded" ]]; then
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
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-cp4a-wfps-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
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
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Workflow Process Service operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"

    # Check IBM CP4BA Insights Engine operator upgrade status
    if [[ "$check_mode" == "full" ]]; then
        echo "****************************************************************************"
        info "Checking for IBM CP4BA Insights Engine operator pod initialization"
        for ((retry=0;retry<=${maxRetry};retry++)); do
            isReady=$(kubectl get csv ibm-insights-engine-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
            # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
            if [[ -z $isReady ]]; then
                csv_version=""
                csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-insights-engine-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
                if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                    if [[ $retry -eq ${maxRetry} ]]; then
                        fail "Failed to upgrade the IBM CP4BA Insights Engine operator to ibm-insights-engine-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                        msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                        exit 1
                    else
                        sleep 30
                        echo -n "..."
                        continue
                    fi
                fi
            elif [[ $isReady != "Succeeded" ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout Waiting for IBM CP4BA Insights Engine operator to start"
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
                echo "oc describe pod $(oc get pod -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
                echo "oc describe rs $(oc get rs -n $project_name|grep ibm-insights-engine-operator|awk '{print $1}') -n $project_name"
                printf "\n"
                exit 1
                else
                sleep 30
                echo -n "..."
                continue
                fi
            elif [[ $isReady == "Succeeded" ]]; then
                if [[ "$check_channel" != "channel" ]]; then
                    pod_name=$(kubectl get pod -l=name=ibm-insights-engine-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                    if [ -z $pod_name ]; then
                        error "IBM CP4BA Insights Engine operator pod is NOT running"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                        break
                    else
                        success "IBM CP4BA Insights Engine operator is running"
                        info "Pod: $pod_name"
                        CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                        break
                    fi
                elif [[ "$check_channel" == "channel" ]]; then
                    success "IBM CP4BA Insights Engine operator is in the phase of \"$isReady\"!"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            fi
        done
        echo "****************************************************************************"
    fi

    # Check CP4BA IBM CP4BA Process Federation Server operator upgrade status
    echo "****************************************************************************"
    info "Checking for IBM CP4BA Process Federation Server operator pod initialization"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReady=$(kubectl get csv ibm-pfs-operator.$CP4BA_CSV_VERSION --no-headers --ignore-not-found -n $project_name -o jsonpath='{.status.phase}')
        # isReady=$(kubectl exec $cpe_pod_name -c ${meta_name}-cpe-deploy -n $project_name -- cat /opt/ibm/version.txt |grep -F "P8 Content Platform Engine 23.0.1")
        if [[ -z $isReady ]]; then
            csv_version=""
            csv_version=$(kubectl get csv $(kubectl get csv --no-headers --ignore-not-found -n $project_name | grep ibm-pfs-operator.v |awk '{print $1}') --no-headers --ignore-not-found -n $project_name -o jsonpath='{.spec.version}')
            if [[ "v$csv_version" != $CP4BA_CSV_VERSION ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then
                    fail "Failed to upgrade the IBM CP4BA Process Federation Server operator to ibm-pfs-operator.$CP4BA_CSV_VERSION under project \"$project_name\"" 
                    msg "Check the Subscription and ClusterServiceVersions and then fix issue firstly."
                    exit 1
                else
                    sleep 30
                    echo -n "..."
                    continue
                fi
            fi
        elif [[ $isReady != "Succeeded" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
            printf "\n"
            warning "Timeout Waiting for IBM CP4BA Process Federation Server operator to start"
            echo -e "\x1B[1mPlease check the status of Pod by issue cmd:\x1B[0m"
            echo "oc describe pod $(oc get pod -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            echo -e "\x1B[1mPlease check the status of ReplicaSet by issue cmd:\x1B[0m"
            echo "oc describe rs $(oc get rs -n $project_name|grep ibm-pfs-operator|awk '{print $1}') -n $project_name"
            printf "\n"
            exit 1
            else
            sleep 30
            echo -n "..."
            continue
            fi
        elif [[ $isReady == "Succeeded" ]]; then
            if [[ "$check_channel" != "channel" ]]; then
                pod_name=$(kubectl get pod -l=name=ibm-pfs-operator -n $project_name -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' --no-headers --ignore-not-found | grep 'Running' | grep 'true' | grep '<none>' | head -1 | awk '{print $1}')
                if [ -z $pod_name ]; then
                    error "IBM CP4BA Process Federation Server operator pod is NOT running"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "FAIL" )
                    break
                else
                    success "IBM CP4BA Process Federation Server operator is running"
                    info "Pod: $pod_name"
                    CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                    break
                fi
            elif [[ "$check_channel" == "channel" ]]; then
                success "IBM CP4BA Process Federation Server operator is in the phase of \"$isReady\"!"
                CHECK_CP4BA_OPERATOR_RESULT=( "${CHECK_CP4BA_OPERATOR_RESULT[@]}" "PASS" )
                break
            fi
        fi
    done
    echo "****************************************************************************"
}

function check_cp4ba_deployment_status(){
    local project_name=$1
    # local meta_name=$2

    UPGRADE_STATUS_CONTENT_FOLDER=${TEMP_FOLDER}/${project_name}
    UPGRADE_STATUS_CP4BA_FOLDER=${TEMP_FOLDER}/${project_name}
    mkdir -p ${UPGRADE_STATUS_CONTENT_FOLDER}
    mkdir -p ${UPGRADE_STATUS_CP4BA_FOLDER}

    UPGRADE_STATUS_CONTENT_FILE=${UPGRADE_STATUS_CONTENT_FOLDER}/.content_status.yaml
    UPGRADE_STATUS_CP4BA_FILE=${UPGRADE_STATUS_CP4BA_FOLDER}/.icp4acluster_status.yaml
    UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME/custom_resource/backup/icp4acluster_cr_backup.yaml
    UPGRADE_DEPLOYMENT_CONTENT_CR_BAK=${CUR_DIR}/cp4ba-upgrade/project/$TARGET_PROJECT_NAME/custom_resource/backup/content_cr_backup.yaml

    cp4ba_cr_name=$(kubectl get icp4acluster -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$cp4ba_cr_name" ]; then
        cp4ba_cr_metaname=$(kubectl get icp4acluster $cp4ba_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
        kubectl get icp4acluster $cp4ba_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CP4BA_FILE}
    fi

    content_cr_name=$(kubectl get content -n $project_name --no-headers --ignore-not-found | awk '{print $1}')
    if [ ! -z "$content_cr_name" ]; then
        content_cr_metaname=$(kubectl get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
        kubectl get content $content_cr_name -n ${project_name} --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_CONTENT_FILE}
    fi

    if [[ -z "${cp4ba_cr_name}" && -z "${content_cr_name}" ]]; then
        fail "Not found any content and icp4acluster custom resource files under project \"$project_name\", exiting ..."
        exit 1
    fi

    if [ -z "${cp4ba_cr_name}" ]; then
        UPGRADE_STATUS_FILE=${UPGRADE_STATUS_CONTENT_FILE}
    elif [ ! -z "${cp4ba_cr_name}" ]; then
        UPGRADE_STATUS_FILE=${UPGRADE_STATUS_CP4BA_FILE}
    fi
    
    if [[ ( ! -z "${content_cr_name}" ) || ( ! -z "${cp4ba_cr_name}" ) ]]; then
        if [[ ! -z "${content_cr_name}" ]]; then
            owner_ref=$(kubectl get content $content_cr_name -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.ownerReferences.[0].kind)
            #################### FNCM #######################
            if [[ -z "${owner_ref}" ]]; then
                #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
                initial_app_version=`cat $UPGRADE_DEPLOYMENT_CONTENT_CR_BAK | ${YQ_CMD} r - spec.appVersion`

                source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
                bai_flag=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.content_optional_components.bai`
                if [[ ! -z "$bai_flag" ]]; then
                    bai_flag=$(echo "$bai_flag" | tr '[:upper:]' '[:lower:]')
                    if [[ " ${bai_flag}" == "true" ]]; then
                        source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
                    fi
                fi
            fi
        fi
        if [[ ! -z "${cp4ba_cr_name}" ]]; then
            #this variable is being used to check what the version of CP4BA was used before upgrade and is used later in a check if some alert message is to be printed
            initial_app_version=`cat $UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK | ${YQ_CMD} r - spec.appVersion`
            EXISTING_PATTERN_ARR=()
            EXISTING_OPT_COMPONENT_ARR=()
            existing_pattern_list=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.shared_configuration.sc_deployment_patterns`
            existing_opt_component_list=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.shared_configuration.sc_optional_components`

            #################### FNCM #######################
            if [[ " ${existing_pattern_list[@]}" =~ "workflow-runtime" || " ${existing_pattern_list[@]}" =~ "workflow-authoring" || " ${existing_pattern_list[@]}" =~ "content" || " ${existing_pattern_list[@]}" =~ "document_processing" || "${existing_opt_component_list[@]}" =~ "ae_data_persistence" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/fncm_status.sh
            fi

            #################### ADP #######################
            if [[ " ${existing_pattern_list[@]}" =~ "document_processing" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/adp_status.sh
            fi

            #################### ADS #######################
            if [[ " ${existing_pattern_list[@]}" =~ "decisions_ads" ]]; then
            source ${CUR_DIR}/helper/upgrade/deployment_check/ads_status.sh
            fi

            #################### ODM #######################
            containsElement "decisions" "${existing_pattern_list[@]}"
            odm_Val=$?
            if [[ $odm_Val -eq 0 ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/odm_status.sh
            fi

            #################### RR #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/rr_status.sh

            #################### BAA AE Multiple instance #######################
            AE_ENGINE_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.application_engine_configuration`
            cr_metaname=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - metadata.name`
            if [[ ! -z "$AE_ENGINE_DEPLOYMENT" ]]; then
                item=0
                while true; do
                    ae_config_name=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.application_engine_configuration.[${item}].name`
                    if [[ -z "$ae_config_name" ]]; then
                        break
                    else
                        source ${CUR_DIR}/helper/upgrade/deployment_check/baa_status.sh
                        ((item++))
                    fi
                done
            fi
            #################### BAStudio #######################
            BASTUDIO_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.bastudio_configuration.admin_user`
            if [[ ! -z "$BASTUDIO_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bastudio_status.sh
            fi
            #################### BAI #######################
            if [[ " ${existing_opt_component_list[@]}" =~ "bai" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/bai_status.sh
            fi

            #################### BAML #######################
            BAML_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.baml_configuration`
            if [[ ! -z "$BAML_DEPLOYMENT" ]]; then
                source ${CUR_DIR}/helper/upgrade/deployment_check/baml_status.sh
            fi

            #################### BAW runtime Multiple instance #######################
            BAW_DEPLOYMENT=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.baw_configuration`
            cr_metaname=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - metadata.name`
            if [[ ! -z "$BAW_DEPLOYMENT" ]]; then
                item=0
                while true; do
                    baw_instance_name=`cat $UPGRADE_STATUS_FILE | ${YQ_CMD} r - spec.baw_configuration.[${item}].name`
                    if [[ -z "$baw_instance_name" ]]; then
                        break
                    else
                        source ${CUR_DIR}/helper/upgrade/deployment_check/baw_runtime_status.sh
                        ((item++))
                    fi
                done
            fi
        fi
    fi

    exist_wfps_cr_array=($(kubectl get WfPSRuntime -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_wfps_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            cr_type="WfPSRuntime"
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
            kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/wfps_status.sh
        done

    fi

    exist_pfs_cr_array=($(kubectl get ProcessFederationServer -n $project_name --no-headers --ignore-not-found | awk '{print $1}'))
    if [ ! -z $exist_pfs_cr_array ]; then
        for item in "${exist_wfps_cr_array[@]}"
        do
            cr_type="ProcessFederationServer"
            cr_metaname=$(kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml | ${YQ_CMD} r - metadata.name)
            kubectl get $cr_type ${item} -n $project_name --no-headers --ignore-not-found -o yaml > ${UPGRADE_STATUS_FILE}
            #################### WfPS #######################
            source ${CUR_DIR}/helper/upgrade/deployment_check/pfs_status.sh
        done

    fi
}

function show_cp4ba_upgrade_status() {
    printf '%s %s\n' "$(date)" "[refresh interval: 30s]"
    echo -en "[Press Ctrl+C to exit] \t\t"
    check_cp4ba_deployment_status "${TARGET_PROJECT_NAME}"
    if [[ "${initial_app_version}" != "23.0.2" && (" ${existing_opt_component_list[@]} " =~ "bai" || "${bai_flag}" == "true") ]]; then
        printf "\n"
        echo -e "\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mAFTER UPGRADE THIS CP4BA DEPLOYMENT SUCCESSFULLY, PLEASE REMOVE \"recovery_path\" FROM CUSTOM RESOURCE UNDER \"bai_configuration\" MANUALLY.\x1B[0m"
    fi
}
