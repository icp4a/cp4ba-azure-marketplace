#!/bin/bash
#/*
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2021
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
# */
#
# cpds_deployProj.sh: script to deploy a design project version in the runtime environment
#
#	This operation will need to connect to the design repository in the design/development environment to retrieve the definitions and models 
#   to be deployed in the test/staging/production (runtime)environment.  Deploy will create the metadata in the Content Platform Engine and import the 
#   machine learning models and definitions (ontology) to the ADP in the runtime environment. 
#
# 	This script will call the helper_getUmsToken to extract the UMS tokens for both the design/development as well as the runtime environment.
# 	This script will call the helper_getZENToken script to extract the IAM and Zen tokens for both design and runtime environments.
#
# Runtime parameters required with UMS SSO authentication which are included in the cpds.properies sample file:
#    runtimeUmsUrl, runtimeUmsClientIdSecret, runtimeUser, runtimePwd, runtimeCpdsUrl, runtimeObjectStore
#
# Runtime parameters required with IAM/Zen authentication which are included in the cpds.properies sample file:
#   runtimeUseZen, runtimeZenIamUrl, runtimeZenUrl, runtimeUser, runtimePwd, runtimeCpdsUrl, runtimeObjectStore
#
# Development parameters required with UMS SSO authentication which are included in the cpds.properies sample file:
#    devUmsUrl, devUmsClientId, devUmsClientSecret, devUser, devPwd
#
#  Development parameters required with IAM/Zen authentication which are included in the cpds.properies sample file:
#     runtimeUseZen, runtimeZenIamUrl, runtimeZenUrl,  devUser, devPwd
#
# Development parameters required for the project name and version (parameters also available listed in default cpds.properties.sample files)
#    projectName: The Document Project Designer project name
#    snapshotVersion: The Document Project Designer snapshot/version name
#
# Example to run script using the cpds.properties file for parameter inputs and overriding the Object Store with the one specified on the command line:
#	./cpds_deployProj.sh --file cpds.properties --runtimeObjectStore OS2


#uncomment for debugging
#set -x


######## Constants 
# Provide defaults that can be override by passed in params
# These parameters are for UMS SSO login
#runtimeUmsUrl=https://ums-sso.adp.ibm.com
#runtimeUmsClientId=XXXXXXXXXXXXXX
#runtimeUmsClientSecret=XXXXXXXXXXXXXX

# These parameters are for Zen login
#runtimeUseZen=true
#runtimeZenIamUrl=https://cpd-adp.apps.adp.cp.ibm.com
#runtimeZenUrl=https://cp-console.apps.adp.cp.ibm.com

#General login runtime parameters
#runtimeUser=Admin
#runtimePwd=password

#devUmsUrl=https://ums-sso.development.adp.ibm.com
#devUmsClientId=XXXXXXXXXXXX
#devUmsClientSecret=XXXXXXXXXX

# These parameters are for Zen login
#devUseZen=true
#devZenIamUrl=https://cpd-adp.apps.adp.development.cp.ibm.com
#devZenUrl=https://cp-console.apps.adp.development.cp.ibm.com

#General login development environment parameters
#devUser=DevAdmin
#devPwd=password

#runtimeCpdsUrl=https://cpds.adp.ibm.com
#projectName=PRJ123
#snapshotVersion=v2-2020-10-13-1825
#runtimeObjectStore=OS1

acceptLanguage="en-US"

######### Functions
f_usage()
{
    echo "NAME"
    echo "  $0 -- deploy a project version from design environment into the runtime environment. "
    echo ""
    echo "USAGE: $0  "
    echo "    [--devUmsUrl          url]     "
    echo "    [--devUmsClientId     id]   "
    echo "    [--devUmsClientSecret secret]   " 
    echo "    [--devUseZen      true] "
    echo "    [--devZenIamUrl    url] "
    echo "    [--devZenUrl      url] "
    echo "    [--devUser           user]     "
    echo "    [--devPwd             pwd]"
    echo "    [--runtimeUmsUrl      url] "
    echo "    [--runtimeUmsClientId id] "
    echo "    [--runtimeUmsClientSecret secret] "
    echo "    [--runtimeUseZen      true] "
    echo "    [--runtimeZenIamUrl    url] "
    echo "    [--runtimeZenUrl      url] "
    echo "    [ --runtimeUser       user] "
    echo "    [--runtimePwd         pwd]"
    echo "    [--runtimeCpdsUrl     UrlToConnectToCPDS] "
    echo "    [--projectName        ProjectName]"
    echo "    [--snapshotVersion    ProjectSnapshot]"
    echo "    [--runtimeObjectStore CPE ObjectStore symbolic name]"
    echo "    [--acceptLanguage     language] (default to en-US if not specified)" 
    echo "    [--file               inputFile to store Key/Value pair for arguments]"
    echo "    [-h]"
    echo ""
    echo "The order of arguments passed in can be used to override, given preference to the last one. "
    echo "For example, if you want to extract most arguments from a file except for the runtimeObjectStore,"
    echo "you can pass --file <file> --runtimeObjectStore <os>"
    echo ""
    echo "EXAMPLES:"
    echo ""
    echo "Example to deploy Project with UMS SSO authentication where all required keys are defined. "
    echo "$0 "
    echo "   --devUmsUrl                       https://ums-sso.development.adp.ibm.com"
    echo "   --devUmsClientId                  XXXXXXXXXXXXXXXXXXXX"
    echo "   --devUmsClientSecret              XXXXXXXXXXXXXXXXXXXX"
    echo "   --devUser                         devCCAmember"
    echo "   --devPwd                          devCCAmemberPwd"
    echo "   --runtimeUmsUrl                   https://ums-sso.adp.ibm.com"
    echo "   --runtimeUmsClientId              XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUmsClientSecret          XXXXXXXXXXXXXXXXXXXX"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     PROJ_123"
    echo "   --snapshotVersion                 v2-2020-10-13-1825"
    echo "   --runtimeObjectStore              OS1"
    echo "" 
    echo "Example to deployment Project in a IAM/Zen authentication where all required keys are defined. "
    echo "$0 "
    echo "   --devUseZen                       true"
    echo "   --devZenIamUrl                    https://cpd-adp.apps.adp.development.cp.ibm.com"
    echo "   --devZenUrl                       https://cp-console.apps.adp.development.cp.ibm.com"
    echo "   --devUser                         devCCAmember"
    echo "   --devPwd                          devCCAmemberPwd"
    echo "   --runtimeUseZen                   true"
    echo "   --runtimeZenIamUrl                https://cpd-adp.apps.adp.cp.ibm.com"
    echo "   --runtimeZenUrl                   https://cp-console.apps.adp.cp.ibm.com"
    echo "   --runtimeUser                     runtimeCCAmember"
    echo "   --runtimePwd                      runtimeCCAmemberPwd"
    echo "   --runtimeCpdsUrl                  https://cpds.adp.ibm.com"
    echo "   --projectName                     PROJ_123"
    echo "   --snapshotVersion                 v2-2020-10-13-1825"
    echo "   --runtimeObjectStore              OS1"
    echo ""
    echo "Example to deploy a Project where all required keys are defined in cpds.properties file. "
    echo "$0 "
    echo "   --file cpds.properties		       where filename contains a list of key/value pairs."
    echo "                                     One can specify all required args in the file."
    echo ""
    echo "Example to deploy a Project where all required keys are defined in cpds.properties file and overriding --projectName. "
    echo "$0 "
    echo "   --file cpds.properties --projectName PROJECT2 "
    echo "                                    to extract all params from filename except for projectName"
    echo "                                    Note: order is important. The overriding argument should be listed last."
}

f_extractFieldsFromFile()
{
	echo 'Extracting fields from file' $INPUT_FILE ......
	if [ ! -z $INPUT_FILE ]
	then
    	set -a
    	. "$INPUT_FILE"
    	set +a
    fi

}

####### Main
if [[ $# = 0 ]]; then 
	echo "Parameters are required."
    f_usage
    exit 1
fi

#parse arg
while [ "$1" != "" ]; do
    case $1 in
        --runtimeUmsUrl )       shift
                                runtimeUmsUrl="$1"
                                ;;
        --runtimeUmsClientId)   shift
								runtimeUmsClientId="$1"
                                ;;
        --runtimeUmsClientSecret)   shift
								runtimeUmsClientSecret="$1"
                                ;;   
        --runtimeZenIamUrl )       shift
                                runtimeZenIamUrl="$1"
                                ;;
        --runtimeUseZen )      shift
                                runtimeUseZen="$1"
                                ;;                        
        --runtimeZenUrl )      shift
                                runtimeZenUrl="$1"
                                ;;                         
        --runtimeUser)    		shift
								runtimeUser="$1"
                                ;;
        --runtimePwd)        	shift
								runtimePwd="$1"
                                ;;
        --devUmsUrl )        	shift
                                devUmsUrl="$1"
                                ;;
        --devUmsClientId)       shift
								devUmsClientId="$1"
                                ;;
        --devUmsClientSecret)   shift
								devUmsClientSecret="$1"
                                ;; 
        --devZenIamUrl )        shift
                                runtimeZenIamUrl="$1"
                                ;;
        --devUseZen )           shift
                                runtimeUseZen="$1"
                                ;;                        
        --devZenUrl )           shift
                                runtimeZenUrl="$1"
                                ;;                                                 
        --devUser)    			shift
								devUser="$1"
                                ;;
        --devPwd)        		shift
								devPwd="$1"
                                ;;
        --runtimeCpdsUrl )      shift
                                runtimeCpdsUrl="$1"
                                ;;
        --projectName)         	shift
								projectName="$1"
                                ;;
        --snapshotVersion)    	shift
								snapshotVersion="$1"
                                ;;
        --runtimeObjectStore)   shift
								runtimeObjectStore="$1"
                                ;;
        --acceptLanguage)		shift
								acceptLanguage="$1"
								;;
        --file)                 shift
								INPUT_FILE="$1"
								f_extractFieldsFromFile
								;;
        -h)                     f_usage
                                exit 1
    esac
    shift
done




# Extract Bearer token to Runtime environment to connect to CPE/ACA, add acceptLang
if [ -z "${runtimeUseZen}" ] || [ "${runtimeUseZen}" != true ]
 then
	CMD="./helper_getUMSToken.sh --acceptLanguage ${acceptLanguage} --url ${runtimeUmsUrl} --id ${runtimeUmsClientId} --secret ${runtimeUmsClientSecret} --usr ${runtimeUser} --pwd ${runtimePwd}"
	echo Getting RunTime UMSToken ... 
	#${CMD}
	RUN_BEARER=$(${CMD})
 else
	CMD="./helper_getZENToken.sh --acceptLanguage ${acceptLanguage} --iamurl ${runtimeZenIamUrl} --zenurl ${runtimeZenUrl} --usr ${runtimeUser} --pwd ${runtimePwd}"
	echo Getting RunTime ZENToken ...
	#${CMD}
	RUN_BEARER=$(${CMD})
fi
#echo

# Extract Bearer token to Design/Development environment to connect to Design Repository 
if [ -z "${devUseZen}" ] || [ "${devUseZen}" != true ]
 then
	CMD="./helper_getUMSToken.sh --acceptLanguage ${acceptLanguage} --url ${devUmsUrl} --id ${devUmsClientId} --secret ${devUmsClientSecret} --usr ${devUser} --pwd ${devPwd}"
	echo Getting Dev UMSToken ... 
	#${CMD}
	DEV_BEARER=$(${CMD})
 else
	CMD="./helper_getZENToken.sh --acceptLanguage ${acceptLanguage} --iamurl ${devZenIamUrl} --zenurl ${devZenUrl} --usr ${devUser} --pwd ${devPwd}"
	echo Getting Dev ZENToken ...
	#${CMD}
	DEV_BEARER=$(${CMD})
fi
#echo 

# Call CPDS deploy REST pass in both bearer tokens with different header
#set -x
echo Deploying project ...
echo If deployment takes a long time, 
echo 1. You can run cpds_getDeployedProjSnapshot.sh to return the overview information about the deployed project version.
echo 2. You can run cpds_getDeploymentRec.sh, pass in a deploymentRecordId from in the previous step retrieved lastDeploymentRecordId value, to retrieve detailed progress.
curl -X POST --header "Accept-Language:${acceptLanguage}" --header 'Content-Type:application/json' --header "X-DBA-DEVToken: ${DEV_BEARER}" --header 'Accept:application/json' --header "Authorization:Bearer ${RUN_BEARER}" -w '\nReturn Code=%{http_code}\n\n' "${runtimeCpdsUrl}/ibm-dba-content-deployment/v1/deployment/projects/${projectName}/branches/master/snapshots/${snapshotVersion}?repositoryIdentifier=${runtimeObjectStore}" -k
