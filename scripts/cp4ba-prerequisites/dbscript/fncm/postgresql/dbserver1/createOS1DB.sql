-- create user db2inst1
CREATE ROLE db2inst1 WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Psiadmin1';
-- please modify location follow your requirement
create tablespace os1db_tbs owner db2inst1 location '/pgsqldata/os1db';
grant create on tablespace os1db_tbs to db2inst1;  
-- create database os1db
create database os1db owner db2inst1 tablespace os1db_tbs template template0 encoding UTF8 ;
-- Connect to your database and create schema
\c os1db;
CREATE SCHEMA IF NOT EXISTS db2inst1 AUTHORIZATION db2inst1;
GRANT ALL ON schema db2inst1 to db2inst1;
-- create a schema for os1db and set the default
-- connect to the respective database before executing the below commands
SET ROLE db2inst1;
ALTER DATABASE os1db SET search_path TO db2inst1;
revoke connect on database os1db from public;
