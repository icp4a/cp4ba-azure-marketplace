#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2023. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

#Options
HELP="false"

while getopts 'n:h' OPTION; do
	case "$OPTION" in
	n)	CP4BA_NAMESPACE=$OPTARG
		;;
	h)
		HELP="true"
		;;
	?)
		HELP="true"
		;;
	esac
done
shift "$(($OPTIND - 1))"

if [[ $HELP == "true" ]]; then
	echo "This script cleans up resources that are stuck in terminating state or would cause failure in re-deployment."
	echo "Usage: $0 -h -n"
	echo "  -h  Display help"
	echo "  -n  Enter CP4BA namespace for clean up."
	exit 0
fi

# Check if OpenShift CLI is installed
if ! [ -x "$(command -v oc)" ]; then
  echo -e "\x1B[1;31mError: OpenShift CLI (oc) is not installed. Please install OpenShift CLI (oc) before running this script. \x1B[0m" >&2
  exit 1
fi

# Check if user is logged in to OCP cluster.
oc project > /dev/null 2>&1
if [ $? -gt 0 ]; then
  echo -e "\x1B[1;31mError: Not logged in to OCP cluster. Please login to an OCP cluster. \x1B[0m" && exit 1
fi

# CP4BA Namespace check
while [ -z "$CP4BA_NAMESPACE" ]; do
	echo -e "\x1B[1mEnter namespace of your CP4BA deployment: \x1B[0m"
	read -rp "" ans 
    CP4BA_NAMESPACE=$ans
    if [ -z "$(oc get project "${CP4BA_NAMESPACE}" 2>/dev/null)" ]; then
	    echo -e "\x1B[1;31mError: Namespace ${CP4BA_NAMESPACE} does not exist. Please re-enter the namespace.\x1B[0m"
        CP4BA_NAMESPACE=""
    fi
    echo
done

# Validate CP4BA_NAMESPACE env var is for existing namespace
if [ -z "$(oc get project "${CP4BA_NAMESPACE}" 2>/dev/null)" ]; then
	echo -e "\x1B[1;31mError: Namespace ${CP4BA_NAMESPACE} does not exist. Specify an existing namespace where CP4BA is deployed.\x1B[0m" && exit 1
fi

# Check for namespace to prvent accidental deletion to other important namespaces.
if [[ "$CP4BA_NAMESPACE" == openshift* ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'openshift' or start with 'openshift'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == kube* ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'kube' or start with 'kube'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "services" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'services'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "default" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'default'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "calico-system" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'calico-system'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-cert-store" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'ibm-cert-store'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-observe" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'ibm-observe'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-odf-validation-webhook" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'default'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
elif [[ "$CP4BA_NAMESPACE" == "ibm-system" ]]; then
    echo -e "\x1B[1;31mThe current namespace should not be 'ibm-system'. It should be the namespace where CP4BA is installed. The script aborted. \x1B[0m"
    exit 1
fi

echo -e "The CP4BA namespace entered: ${CP4BA_NAMESPACE}\n"
echo -e "\x1B[1mNote: Please make sure you are using the namespace you intent to clean up.\n\x1B[0m"
echo -e "\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mThis clean-up script is only intended to be run after you have deleted your ICP4ACluster or Content CR instance for your CP4BA deployment. This clean-up script will delete all Client CRs and zenExtensions, and some secrets that would cause failure in re-deployment. \x1B[0m\n"

# Confirm to clean up
echo -e "\x1B[1mPlease confirm if you would like to proceed with this clean up.\x1B[0m"
read -p "Enter Y or y to continue: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\nYou did not confirm to proceed with this clean up. Exit clean-up script."
    exit 0
  fi
  echo -e "You have confirmed to continue this clean up.\n"
  sleep 2

function delete_resource() {
	local RESOURCE_NAME=$1
	local NAMESPACE_NAME=$2
	oc get "${RESOURCE_NAME}" -n "${NAMESPACE_NAME}" --ignore-not-found=true &>/dev/null
	if [ $? -eq 0 ]; then
		for i in $(oc get "${RESOURCE_NAME}" --no-headers -n "${NAMESPACE_NAME}" --ignore-not-found=true | awk '{print $1}'); do
			oc patch "${RESOURCE_NAME}"/"$i" -n "${NAMESPACE_NAME}" -p '{"metadata":{"finalizers":[]}}' --type=merge
			oc delete "${RESOURCE_NAME}" "$i" -n "${NAMESPACE_NAME}" --ignore-not-found=true
		done
	fi
}

# Clean up clients
echo -e "\x1B[1mCleaning up Clients... \x1B[0m\n"
delete_resource client "${CP4BA_NAMESPACE}"
echo -e "\n\x1B[1mFinsished cleaning up all Clients. \x1B[0m\n"
# Clean up zenExtension
echo -e "\x1B[1mCleaning up zenExtensions... \x1B[0m\n"
delete_resource zenextension "${CP4BA_NAMESPACE}"
echo -e "\n\x1B[1mFinsihed cleaning up all zenExtensions. \x1B[0m\n"
# Clean up zen-metastore-edb secret
echo -e "\x1B[1mCleaning up zen-metastore-edb secrets... \x1B[0m\n"
for i in $(oc get secrets --no-headers|awk '{print $1}'| grep 'zen-metastore-edb'); do
    oc delete secret "$i" -n "$CP4BA_NAMESPACE"
done
echo -e "\n\x1B[1mFinsihed cleaning up all zen-metastore-edb related secrets. \x1B[0m\n"
# Clean up cs-ca-certificate secret
echo -e "\x1B[1mCleaning up cs-ca-certificate-secret secret... \x1B[0m\n"
oc delete secret cs-ca-certificate-secret -n "$CP4BA_NAMESPACE"
echo -e "\n\x1B[1mFinsihed cleaning up cs-ca-certificate-secret secret. \x1B[0m\n"
echo -e "\x1B[1mCP4BA clean up has completed.\x1B[0m\n"