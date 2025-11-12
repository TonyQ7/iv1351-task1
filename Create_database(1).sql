-- 01_create_database_windows.sql
-- Use this on Windows to avoid collation mismatches.
-- Run in the 'postgres' maintenance DB.
DROP DATABASE IF EXISTS dsp_university;
CREATE DATABASE dsp_university
  WITH OWNER = postgres
       ENCODING = 'UTF8';
