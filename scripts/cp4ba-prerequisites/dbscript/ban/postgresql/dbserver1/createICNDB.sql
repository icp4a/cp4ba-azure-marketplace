-- create user db2inst1
CREATE ROLE db2inst1 WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Psiadmin1';
-- please modify location follow your requirement
create tablespace icndb_tbs owner db2inst1 location '/pgsqldata/icndb';
grant create on tablespace icndb_tbs to db2inst1;  

-- create database icndb
create database icndb owner db2inst1 tablespace icndb_tbs template template0 encoding UTF8 ;
\c icndb;
CREATE SCHEMA IF NOT EXISTS db2inst1 AUTHORIZATION db2inst1;
GRANT ALL ON schema db2inst1 to db2inst1;

-- create a schema for icndb and set the default
-- connect to the respective database before executing the below commands
SET ROLE db2inst1;
ALTER DATABASE icndb SET search_path TO db2inst1;
revoke connect on database icndb from public;
