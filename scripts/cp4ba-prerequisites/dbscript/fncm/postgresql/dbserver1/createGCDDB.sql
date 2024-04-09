-- create user db2inst1
CREATE ROLE db2inst1 WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Psiadmin1';
-- please modify location follow your requirement
create tablespace gcddb_tbs owner db2inst1 location '/pgsqldata/gcddb';
grant create on tablespace gcddb_tbs to db2inst1; 
-- create database gcddb
create database gcddb owner db2inst1 tablespace gcddb_tbs template template0 encoding UTF8 ;
-- Connect to your database and create schema
\c gcddb;
CREATE SCHEMA IF NOT EXISTS db2inst1 AUTHORIZATION db2inst1;
GRANT ALL ON schema db2inst1 to db2inst1;
-- create a schema for gcddb and set the default
-- connect to the respective database before executing the below commands
SET ROLE db2inst1;
ALTER DATABASE gcddb SET search_path TO db2inst1;
revoke connect on database gcddb from public;
