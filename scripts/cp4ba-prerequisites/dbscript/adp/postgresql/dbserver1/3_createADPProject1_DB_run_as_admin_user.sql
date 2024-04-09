--
-- IMPORTANT: Run this script as the Postgres user with admin privileges to create a database.
--

CREATE DATABASE "proj1" owner "db2inst1" template template0 encoding UTF8;

REVOKE CONNECT ON DATABASE "proj1" FROM PUBLIC;

GRANT ALL ON DATABASE "proj1" TO "db2inst1";
