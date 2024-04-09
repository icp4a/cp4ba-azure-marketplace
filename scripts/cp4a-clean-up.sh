#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

#Default Namespace
CPFS_SHARED_NAMESPACE="ibm-common-services"
CPFS_CONTROL_NAMESPACE="cs-control"
IBM_CERT_MANAGER_NAMESPACE="ibm-cert-manager"
IBM_LICENSING_NAMESPACE="ibm-licensing"
OPENSHIFT_OPERATORS_NAMESPACE="openshift-operators"

#Options
HELP="false"
SKIP_CONFIRM="false"
SELECT_ALL="false"

while getopts 'n:hsa' OPTION; do
	case "$OPTION" in
	n)	CP4BA_NAMESPACE=$OPTARG
		;;
	h)
		HELP="true"
		;;
	s)
		SKIP_CONFIRM="true"
		;;
	a)
		SELECT_ALL="true"
		;;
	?)
		HELP="true"
		;;
	esac
done
shift "$(($OPTIND - 1))"

if [[ $HELP == "true" ]]; then
	echo "This script completely cleans up IBM Cloud Pak for Business Automation and IBM Cloud Pak foundational services."
	echo "Usage: $0 -h -n"
	echo "  -h  Display help"
	echo "  -n  Enter CP4BA namespace for clean up."
	echo "  -s  Use this option to skip confirmation."
	exit 0
fi

if ! [ -x "$(command -v oc)" ]; then
	echo -e "\x1B[1;31mError: oc is not installed. \x1B[0m"
	exit 1
fi

oc project > /dev/null 2>&1
if [ $? -gt 0 ]; then
	echo -e "\x1B[1;31mError: oc login is required for running this script. \x1B[0m"
	exit 1
fi

# CP4BA Namespace check
if [ -z "$CP4BA_NAMESPACE" ]; then
	echo -e "\x1B[1;31mERROR: CP4BA namespace needed. Please enter the CP4BA namespace following -n or use -h for more details. \x1B[0m"
	exit 1
fi

# Namespace check to avoid cleaning up in the wrong namespace
if [[ "$CP4BA_NAMESPACE" == openshift* ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'openshift' or start with 'openshift'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == kube* ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'kube' or start with 'kube'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "services" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'services'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "default" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'default'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "calico-system" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'calico-system'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-cert-store" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'ibm-cert-store'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-observe" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'ibm-observe'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-odf-validation-webhook" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'ibm-odf-validation-webhook'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-system" ]]; then
	echo -e "\x1B[1;31mThen entered namespace should not be 'ibm-system'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
	exit 1
fi

# Validate CP4BA_NAMESPACE env var is for existing namespace
if [ -z "$(oc get project "${CP4BA_NAMESPACE}" 2>/dev/null)" ]; then
	echo "Error: namespace ${CP4BA_NAMESPACE} does not exist. Specify an existing namespace where CP4BA is installed." && exit 1
fi

echo -e "The CP4BA namespace entered:\n - ${CP4BA_NAMESPACE}\n"
echo -e "Note: Please make sure you have entered the namespace you intended to clean up.\n"
echo -e "\033[32m[\xE2\x9C\x94]All prerequsite passed. Ready for clean up.\033[0m"
echo
echo -e "\x1B[33;5mATTENTION: \x1B[0m\x1B[1;33mThis clean-up script is only intend to delete any remaining resources in the Cloud Pak for Business Automation and Cloud Pak foundational services namespace(s). This clean-up script is not intended for uninstalling Cloud Pak for Business Automation and Cloud Pak foundational services deployment. \x1B[0m\n"

# CPFS shared check
CPFS_SHARED_NAMESPACE=$(oc get configmap common-service-maps  -n kube-public -o jsonpath='{.data}' | grep -oP "(?<=map-to-common-service-namespace: )(.*)(?=requested-from-namespace:)" | tr -d '\\n' | tr -s ' ')
echo -e "Cloud Pak foundational services namespace:\n - ${CPFS_SHARED_NAMESPACE}"
NAMESPACESTR=$(oc get configmap common-service-maps  -n kube-public -o jsonpath='{.data}' | grep -oP '(?<=requested-from-namespace:)(.*)(?=\"\})' | tr -d '\\n')
NAMESPACEARR=(${NAMESPACESTR//- / })
COUNT=1
if [[ "${#NAMESPACEARR[@]}" -gt "0" ]]; then
	echo -e "\nList of namespace(s) that use Cloud Pak foundational services:"
fi
for NS in "${NAMESPACEARR[@]}"; do
  echo "${COUNT}) ${NS}"
  ((COUNT+=1))
done

echo -e "\nNote: This clean-up script does not support cleaning up Shared Cloud Pak foundational services.\n"

if [[ "${#NAMESPACEARR[@]}" -gt "1" ]]; then
	echo -e "\x1B[1;31mThere are multiple namespaces sharing Cloud Pak foundational services. This script does not support cleaning up shared Cloud Pak foundational services. The script aborted.\x1B[0m"
	exit 1
fi

if [[ "${NAMESPACEARR[0]}" !=  "${CP4BA_NAMESPACE}" ]]; then
	echo -e "\x1B[1;31mCloud Pak for Business Automation namespace does not match namespace entered. The script aborted.\x1B[0m"
	exit 1
fi

if [[ "${#NAMESPACEARR[@]}" -eq "1" ]]; then
	echo -e "\033[32m\n[\xE2\x9C\x94]Cloud Pak foundational services is not shared. Clean-up may continue.\n\x1B[0m"
fi

# Check if Multiple CP4BA is installed in the same cluster
CLEAN_CRDS="false"
while true; do
	echo -e "\x1B[1mAre there multiple CP4BA deployments on your cluster? (Yes/No, default: Yes)\x1B[0m"
	read -rp "" ans 
	ans=$(echo "${ans}" | tr '[:upper:]' '[:lower:]')
	case "$ans" in
	"y"|"yes"|"")
		echo -e "There are multiple CP4BA deployments, CustomResourceDefinitions will not be cleaned up."
	break
	;;
	"n"|"no")
		echo -e "There is only one CP4BA deployment, CustomResourceDefinitions will be cleaned up."
		CLEAN_CRDS="true"
	break
	;;
	*)
	echo -e "Answer must be 'Yes' or 'No'\n"
	esac
done
sleep 2
# Get Resource function
function get_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	oc get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(oc get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true| awk '{print $1}'); do
			echo "${RESOURCE_NAME}/${i}"
		done
	fi
}

function delete_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	oc get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(oc get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true | awk '{print $1}'); do
			oc patch "${RESOURCE_NAME}"/$i -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
			oc delete "${RESOURCE_NAME}" $i -n "${NAMESPACE_NAME}" --ignore-not-found=true --wait=true
		done
	fi
}

# Print resource report
CP4BA_RESOURCES=(
	"cartridgerequirements"
	"automationbase"
	"kafka"
	"elasticsearch"
	"zenservice"
	"cartridge"
	"kafkaclaim"
	"kafkacomposite"
	"clients.oidc.security.ibm.com"
	"icp4aads"
	"pfs"
	"icp4aodm"
	"icp4adocumentprocessingengine"
	"operandrequest"
	"commonservice"
	"operandregistry"
	"operandconfig"
	"nss"
	"issuer"
	"certificate"
	"certificaterequests"
	"csv"
	"sub"
	"zenextension"
	"authentications.operator.ibm.com"
	"namespacescope"
	"operandbindinfo"
	"policycontroller.operator.ibm.com"
	"authentications.operator.ibm.com"
	"nginxingresses.operator.ibm.com"
	"oidcclientwatcher.operator.ibm.com"
	"oidcclientwatchers.operator.ibm.com"
	"commonui.operator.ibm.com"
	"commonui1.operator.ibm.com"
	"commonwebuis.operator.ibm.com"
	"commonwebuis.operators.ibm.com"
	"platformapis.operator.ibm.com"
	"certmanagers"
	"rolebindings.authorization.openshift.io"
	"rolebindings.rbac.authorization.k8s.io"
	"configuration"
	"providerconfig"
	"lock"
	"compositeresourcedefinitions"
	"configurationrevisions"
)
echo -e "\n\033[1mResources in CP4BA Namespace: ${CP4BA_NAMESPACE}\033[0m"
for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
	get_resource "${RESOURCE}" "${CP4BA_NAMESPACE}"
done

for i in $(oc get pv --no-headers -n "${CP4BA_NAMESPACE}" | grep "operator-shared-pv*" | awk '{print $1}'); do
	echo "pv/${i}"
done
for i in $(oc get operators --no-headers | grep "${CP4BA_NAMESPACE}" | awk '{print $1}'); do
	echo "operators/${i}"
done

# CPFS Resource
CPFS_RESOURCES=(
	"operandrequest"
	"commonservice"
	"operandregistry"
	"operandconfig"
	"namespacescope"
	"operandbindinfo"
	"policycontroller.operator.ibm.com"
	"authentications.operator.ibm.com"
	"authentications.operator.ibm.com"
	"nginxingresses.operator.ibm.com"
	"oidcclientwatcher.operator.ibm.com"
	"oidcclientwatchers.operator.ibm.com"
	"commonui.operator.ibm.com"
	"commonui1.operator.ibm.com"
	"commonwebuis.operator.ibm.com"
	"platformapis.operator.ibm.com"
	"nss"
	"sub"
	"csv"
	"deploy"
	"sts"
	"job"
	"svc"
	"rolebindings.authorization.openshift.io"
	"rolebindings.rbac.authorization.k8s.io"
	"objects"
)

# Get CPFS Shared namespace resources
echo -e "\n\033[1mResources in CPFS Namespace: ${CPFS_SHARED_NAMESPACE}\033[0m"
for RESOURCE in "${CPFS_RESOURCES[@]}"; do
	get_resource "${RESOURCE}" "${CPFS_SHARED_NAMESPACE}"
done

#Check CPFS Control namespace exist
oc get project ${CPFS_CONTROL_NAMESPACE} &>/dev/null
if [ $? -eq 0 ]; then
	# Get CPFS Control namespace resources
	echo -e "\n\033[1mResource in Namespace: ${CPFS_CONTROL_NAMESPACE}\033[0m"
	for RESOURCE in "${CPFS_RESOURCES[@]}"; do
		get_resource "${RESOURCE}" "${CPFS_CONTROL_NAMESPACE}"
	done
fi

#Get webhook
echo -e "\n\033[1mWebhook:\033[0m"
pattern2="ibm-cs-ns-mapping-webhook-configuration"
pattern3="ibm-common-service-validating-webhook"
pattern4="namespace-admission-config"
pattern5="ibm-operandrequest-webhook-configuration"
pattern6="ibm-common-service-webhook-configuration"

webhook_configs=$(oc get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern2|$pattern3")
for webhook in $webhook_configs; do
    echo -e "ValidatingWebhookConfiguration/${webhook}"
done

webhook_configs=$(oc get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern4|$pattern5|$pattern6")
for webhook in $webhook_configs; do
    echo -e "MutatingWebhookConfiguration/${webhook}"
done

# Get CRDs
if [[ $CLEAN_CRDS == "true" ]]; then
	CP4BA_CRDS=(
		"contentrequests.icp4a.ibm.com"
		"contents.icp4a.ibm.com"
		"foundationrequests.icp4a.ibm.com"
		"foundations.icp4a.ibm.com"
		"icp4aclusters.icp4a.ibm.com"
		"processfederationservers.icp4a.ibm.com"
		"wfpsruntimes.icp4a.ibm.com"
		"documentprocessingengines.dpe.ibm.com"
		"icp4aoperationaldecisionmanagers.icp4a.ibm.com"
		"icp4aautomationdecisionservices.icp4a.ibm.com"
	)
	echo -e "\n\033[1mCRDs:\033[0m"
	for i in "${CP4BA_CRDS[@]}"; do
		oc get crd $i &>/dev/null
		if [ $? -eq 0 ]; then
			echo "crd/${i}"
		fi
	done
fi

# Configmaps for CPFS
echo -e "\n\033[1mConfigmaps in kube-public namespace:\033[0m"
for i in $(oc get cm common-service-maps ibm-common-services-status -n kube-public --ignore-not-found --no-headers | awk '{print $1}'); do
	echo "cm/${i}"
done

# Role
echo -e "\n\033[1mOther Resources:\033[0m"
for i in $(oc get ClusterRoleBinding ibm-common-service-webhook secretshare-ibm-common-services $(oc get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found --no-headers | awk '{print $1}'); do
	echo "ClusterRoleBinding/${i}"
done
for i in $(oc get ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found --no-headers | awk '{print $1}'); do
	echo "ClusterRole/${i}"
done
for i in $(oc get RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found --no-headers | awk '{print $1}'); do
	echo "RoleBinding/${i}"
done
for i in $(oc get Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found --no-headers | awk '{print $1}'); do
	echo "Role/${i}"
done
for i in $(oc get scc nginx-ingress-scc --ignore-not-found --no-headers | awk '{print $1}'); do
	echo "scc/${i}"
done

# Get apiservice
oc get apiservice v1beta1.webhook.certmanager.k8s.io &>/dev/null
if [ $? -eq 0 ]; then
	echo "apiservice/v1beta1.webhook.certmanager.k8s.io"
fi
oc get apiservice v1.metering.ibm.com &>/dev/null
if [ $? -eq 0 ]; then
	echo "apiservice/v1.metering.ibm.com"
fi

# Clean up confirmation
if [[ $SKIP_CONFIRM == "false" ]]; then
	echo -e "\nNote: The list above are resources remaining in the namespaces that will be cleaned up."
	echo -e "\nThis script will clean up IBM Cloud Pak for Business Automation and IBM Cloud Pak foundational services namespace, including deleting the namespace where your CP4BA instance is installed.\n"
	read -p "Enter Y or y to continue: " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Clean up not confirmed. Exiting script."
		exit 0
	fi
	echo
	echo "You have confirmed to clean up. Continue to clean up IBM Cloud Pak for Business Automation and IBM Cloud Pak foundational services namespace"
	sleep 2
	echo
fi

# CP4BA clean up
echo -e "\n\033[1mCleaning up resources in CP4BA Namespace: ${CP4BA_NAMESPACE}\033[0m\n"
for RESOURCE in "${CP4BA_RESOURCES[@]}"; do
	delete_resource "${RESOURCE}" "${CP4BA_NAMESPACE}"
done

oc get pv --no-headers | grep "operator-shared-pv*" | grep -E "Available|Failed" | awk '{print $1}' | xargs oc delete pv 2>/dev/null

for i in $(oc get operators --no-headers | grep "${CP4BA_NAMESPACE}" | awk '{print $1}'); do
	oc delete operator "$i"
done

# Clean up CPFS
echo -e "/n\033[1mCleaning up resources in CPFS Namespace: ${CPFS_SHARED_NAMESPACE}\033[0m\n"
for RESOURCE in "${CPFS_RESOURCES[@]}"; do
	delete_resource "${RESOURCE}" "${CPFS_SHARED_NAMESPACE}"
done

# Clean up CPFS control
oc get project ${CPFS_CONTROL_NAMESPACE} &>/dev/null
if [ $? -eq 0 ]; then
	# Delete CPFS Control namespace resources
	echo -e "\033[1mCleaning up resources in Namespace: ${CPFS_CONTROL_NAMESPACE}\033[0m\n"
	for RESOURCE in "${CPFS_RESOURCES[@]}"; do
		delete_resource "${RESOURCE}" "${CPFS_CONTROL_NAMESPACE}"
	done
fi

echo "Delete common service webhook"
pattern2="ibm-cs-ns-mapping-webhook-configuration"
pattern3="ibm-common-service-validating-webhook"
pattern4="namespace-admission-config"
pattern5="ibm-operandrequest-webhook-configuration"
pattern6="ibm-common-service-webhook-configuration"

webhook_configs=$(oc get ValidatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern2|$pattern3 &>/dev/null")
if [ $? -eq 0 ]; then
	for webhook in $webhook_configs; do
		oc delete ValidatingWebhookConfiguration "$webhook"
	done
fi

webhook_configs=$(oc get MutatingWebhookConfiguration -o custom-columns=:metadata.name --no-headers | grep -E "$pattern4|$pattern5|$pattern6 &>/dev/null")
if [ $? -eq 0 ]; then
	for webhook in $webhook_configs; do
		oc delete MutatingWebhookConfiguration "$webhook"
	done
fi

# Cleaning up Role related resources
oc delete ClusterRoleBinding ibm-common-service-webhook secretshare-ibm-common-services $(oc get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found
oc delete ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found
oc delete RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found
oc delete Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found
oc delete scc nginx-ingress-scc --ignore-not-found

# Cleaning up apiservice
oc get apiservice v1beta1.webhook.certmanager.k8s.io 2>/dev/null
if [ $? -eq 0 ]; then
	echo "delete apiservice v1beta1.webhook.certmanager.k8s.io"
	oc delete apiservice v1beta1.webhook.certmanager.k8s.io
fi
oc get apiservice v1.metering.ibm.com 2>/dev/null
if [ $? -eq 0 ]; then
	echo "delete apiservice v1.metering.ibm.com"
	oc delete apiservice v1.metering.ibm.com
fi

# Delete configmaps in kube-public
echo "Delete configmaps from kube-public namespace"
oc delete cm common-service-maps ibm-common-services-status -n kube-public --ignore-not-found


# Delete resource in openshift-operator namespace
if [[ $SELECT_ALL == "true" ]]; then
	echo "Cleaning up openshift-operators namespace"
	oc -n $OPENSHIFT_OPERATORS_NAMESPACE delete operandrequest --force --grace-period=0 --all --ignore-not-found=true --wait=true
	oc delete csv,sub -n $OPENSHIFT_OPERATORS_NAMESPACE --all --ignore-not-found=true --wait=true
	oc -n $OPENSHIFT_OPERATORS_NAMESPACE get cm | grep -E "iaf|ibm|namespace-scope" | awk '{print $1}' | xargs oc delete cm -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	oc -n $OPENSHIFT_OPERATORS_NAMESPACE get sa | grep -E "iaf|ibm|postgresql" | awk '{print $1}' | xargs oc delete sa -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	oc delete rolebinding iaf-insights-engine-operator-leader-election-rolebinding -n $OPENSHIFT_OPERATORS_NAMESPACE
	oc delete lease,secret,svc,netpol,job,deploy,pvc,role --all -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true
	oc delete commonservice,operandregistry,operandconfig --all -n $OPENSHIFT_OPERATORS_NAMESPACE --ignore-not-found=true --wait=true 
	for i in $(oc -n $OPENSHIFT_OPERATORS_NAMESPACE get operandrequest --no-headers | awk '{print $1}'); do
		oc -n $OPENSHIFT_OPERATORS_NAMESPACE patch operandrequest/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
		oc -n $OPENSHIFT_OPERATORS_NAMESPACE delete operandrequest $i --ignore-not-found=true --wait=true
	done
fi

# Removing CRDs
if [[ $CLEAN_CRDS == "true" ]]; then
	for i in "${CP4BA_CRDS[@]}"; do
		oc patch crd/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
		oc delete crd $i --ignore-not-found=true --wait=true
	done
fi

echo "Cleaning up all pods before deleting namespace."
oc delete pod --all -n "$CP4BA_NAMESPACE" --grace-period=0 --force
oc delete pod --all -n "${CPFS_SHARED_NAMESPACE}" --grace-period=0 --force
oc delete pod --all -n "${CPFS_CONTROL_NAMESPACE}" --grace-period=0 --force
oc project default

if [[ ${CP4BA_NAMESPACE} != "openshift-operators" ]]; then

	echo "Deleting project ${CP4BA_NAMESPACE}"
	oc delete project "${CP4BA_NAMESPACE}"

	echo "Wait until namespace ${CP4BA_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${CP4BA_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			echo "Namespace ${CP4BA_NAMESPACE} deletion successful"
			break
		else
			((count += 1))
			if ((count <= 36)); then
				echo "Waiting for namespace ${CP4BA_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				echo "Deleting namespace ${CP4BA_NAMESPACE} is taking too long and giving up"
				oc get project "${CP4BA_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

fi

echo "Deleting namespace ${CPFS_SHARED_NAMESPACE}"
oc delete project "${CPFS_SHARED_NAMESPACE}"

echo "Wait until namespace ${CPFS_SHARED_NAMESPACE} is completely deleted."
count=0
while :; do
	oc get project "${CPFS_SHARED_NAMESPACE}" 2>/dev/null
	if [[ $? -gt 0 ]]; then
		echo "Namespace ${CPFS_SHARED_NAMESPACE} deletion successful"
		break
	else
		((count += 1))
		if ((count <= 36)); then
			echo "Waiting for namespace ${CPFS_SHARED_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
			sleep 10
		else
			echo "Deleting namespace ${CPFS_SHARED_NAMESPACE} is taking too long and giving up"
			oc get project "${CPFS_SHARED_NAMESPACE}" -o yaml
			exit 1
		fi
	fi
done

oc get project "${CPFS_CONTROL_NAMESPACE}" &>/dev/null
if [ $? -eq 0 ]; then
	echo "Deleting namespace ${CPFS_CONTROL_NAMESPACE}"
	oc delete project "${CPFS_CONTROL_NAMESPACE}"
	echo "Wait until namespace ${CPFS_CONTROL_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${CPFS_CONTROL_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			echo "Namespace ${CPFS_CONTROL_NAMESPACE} deletion successful"
			break
		else
			((count += 1))
			if ((count <= 36)); then
				echo "Waiting for namespace ${CPFS_CONTROL_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				echo "Deleting namespace ${CPFS_CONTROL_NAMESPACE} is taking too long and giving up"
				oc get project "${CPFS_CONTROL_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
fi

# For cleaning up IBM Cert Manager and IBM Licensing. DEV and QA only. Using -a option.
if [[ $SELECT_ALL == "true" ]]; then
	# IBM Cert Manager
	oc delete sub,csv --all -n ${IBM_CERT_MANAGER_NAMESPACE} --ignore-not-found=true --wait=true
	oc delete deploy,sts,job,svc --all -n ${IBM_CERT_MANAGER_NAMESPACE} --ignore-not-found=true --wait=true
	oc delete certmanagerconfig --all --ignore-not-found=true --wait=true
	oc delete ValidatingWebhookConfiguration cert-manager-webhook
	oc delete MutatingWebhookConfiguration cert-manager-webhook


	# IBM Licensing
	oc delete ibmlicensing --all -n "${IBM_LICENSING_NAMESPACE}" --ignore-not-found=true --wait=true
	oc delete sub,csv --all -n "${IBM_LICENSING_NAMESPACE}" --ignore-not-found=true --wait=true
	oc delete deploy,sts,job,svc --all -n "${IBM_LICENSING_NAMESPACE}" --ignore-not-found=true --wait=true

	echo "Deleting namespace ${IBM_CERT_MANAGER_NAMESPACE}"
	oc delete project "${IBM_CERT_MANAGER_NAMESPACE}"
	echo "Wait until namespace ${IBM_CERT_MANAGER_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${IBM_CERT_MANAGER_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			echo "Namespace ${IBM_CERT_MANAGER_NAMESPACE} deletion successful"
			break
		else
			((count += 1))
			if ((count <= 36)); then
				echo "Waiting for namespace ${IBM_CERT_MANAGER_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				echo "Deleting namespace ${IBM_CERT_MANAGER_NAMESPACE} is taking too long and giving up"
				oc get project "${IBM_CERT_MANAGER_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done

	echo "Deleting namespace ${IBM_LICENSING_NAMESPACE}"
	oc delete project "${IBM_LICENSING_NAMESPACE}"
	echo "Wait until namespace ${IBM_LICENSING_NAMESPACE} is completely deleted."
	count=0
	while :; do
		oc get project "${IBM_LICENSING_NAMESPACE}" 2>/dev/null
		if [[ $? -gt 0 ]]; then
			echo "Namespace ${IBM_LICENSING_NAMESPACE} deletion successful"
			break
		else
			((count += 1))
			if ((count <= 36)); then
				echo "Waiting for namespace ${IBM_LICENSING_NAMESPACE} to be terminated.  ... Rechecking in  10 seconds"
				sleep 10
			else
				echo "Deleting namespace ${IBM_LICENSING_NAMESPACE} is taking too long and giving up"
				oc get project "${IBM_LICENSING_NAMESPACE}" -o yaml
				exit 1
			fi
		fi
	done
fi

echo "CP4BA and CPFS clean up has completed."