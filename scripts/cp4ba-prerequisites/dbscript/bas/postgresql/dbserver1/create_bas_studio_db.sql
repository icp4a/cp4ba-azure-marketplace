-- create the user
CREATE ROLE db2inst1 WITH INHERIT LOGIN ENCRYPTED PASSWORD 'Psiadmin1';

-- create the database:
CREATE DATABASE basdb WITH OWNER db2inst1 ENCODING 'UTF8';

-- Connect to your database and create schema
\c basdb;
CREATE SCHEMA IF NOT EXISTS db2inst1 AUTHORIZATION db2inst1;
GRANT ALL ON schema db2inst1 to db2inst1;
