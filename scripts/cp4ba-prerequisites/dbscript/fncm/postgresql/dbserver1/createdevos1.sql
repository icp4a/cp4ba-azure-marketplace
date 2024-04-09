-- create user db2inst1
CREATE ROLE db2inst1 WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Psiadmin1';
-- please modify location follow your requirement
create tablespace devos1_tbs owner db2inst1 location '/pgsqldata/devos1';
grant create on tablespace devos1_tbs to db2inst1;  
-- create database devos1
create database devos1 owner db2inst1 tablespace devos1_tbs template template0 encoding UTF8 ;
-- Connect to your database and create schema
\c devos1;
CREATE SCHEMA IF NOT EXISTS db2inst1 AUTHORIZATION db2inst1;
GRANT ALL ON schema db2inst1 to db2inst1;
-- create a schema for devos1 and set the default
-- connect to the respective database before executing the below commands
SET ROLE db2inst1;
ALTER DATABASE devos1 SET search_path TO db2inst1;
revoke connect on database devos1 from public;
