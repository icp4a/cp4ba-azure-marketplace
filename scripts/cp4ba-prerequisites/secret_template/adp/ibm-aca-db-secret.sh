#!/bin/bash
#
# Shell template for creating Document Processing Engine (DPE) DB secret
# Run this script in the namespace or project in which you are deploying CP4BA
#
# ---- Sample format of script ----
# kubectl create secret generic "<YOUR_SECRET_NAME>" \
# --from-literal=BASE_DB_USER="<YOUR_BASE_DB_USER>" \
# --from-literal=BASE_DB_CONFIG="<YOUR_BASE_DB_PWD>" \
# One PROJNAME_DB_CONFIG line for each project database your have
# --from-literal=<YOUR_PROJ_NAME>_DB_CONFIG="<YOUR_PROJ_DB_PWD>" \
# The line below if only needed if using SSL connection for DB2   
# --from-file=CERT="<REPLACE_WITH_PATH_TO_DB2_SSL_CERT_FILE]>"
#
# ---- End of Sample ----

kubectl delete secret generic "aca-basedb" >/dev/null 2>&1
kubectl create secret generic "aca-basedb" \
 --from-literal=BASE_DB_USER="db2inst1" \
 --from-literal=BASE_DB_CONFIG="Psiadmin1" \
 --from-literal=PROJ1_DB_CONFIG="Psiadmin1" \
 --from-literal=PROJ2_DB_CONFIG="Psiadmin1" 
kubectl label --overwrite secret "aca-basedb" base-db-server=dbserver1
kubectl label --overwrite secret "aca-basedb" base-db-name=adpbase
# Please confirm that the values above are correct, and modify as needed.
