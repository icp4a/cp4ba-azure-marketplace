--
-- IMPORTANT: Run this script as the Postgres user db2inst1
--

\c "adpbase" ;

set search_path to "db2inst1" ;

insert into TENANTINFO (tenantid,ontology,tenanttype,dailylimit,rdbmsengine,bacaversion,connstring,dbname,dbuser,tenantdbversion,featureflags,dbstatus,project_guid,bas_id) values ( 'proj2', 'ont1', 0, 0, 'PG', '23.0.2','DB=proj2;USR=db2inst1;SRV=cautil-node2.fyre.ibm.com;PORT=50000;','proj2','db2inst1','23.0.2',154366,0,NULL,NULL) ;
