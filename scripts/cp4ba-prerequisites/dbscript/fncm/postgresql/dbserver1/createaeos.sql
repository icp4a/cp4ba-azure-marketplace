-- create user db2inst1
CREATE ROLE db2inst1 WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Psiadmin1';
-- please modify location follow your requirement
create tablespace aeos_tbs owner db2inst1 location '/pgsqldata/aeos';
grant create on tablespace aeos_tbs to db2inst1;  
-- create database aeos
create database aeos owner db2inst1 tablespace aeos_tbs template template0 encoding UTF8 ;
-- Connect to your database and create schema
\c aeos;
CREATE SCHEMA IF NOT EXISTS db2inst1 AUTHORIZATION db2inst1;
GRANT ALL ON schema db2inst1 to db2inst1;
-- create a schema for aeos and set the default
-- connect to the respective database before executing the below commands
SET ROLE db2inst1;
ALTER DATABASE aeos SET search_path TO db2inst1;
revoke connect on database aeos from public;
