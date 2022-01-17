-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC 
-- MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC   <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning" style="width: 600px">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC # Extract and Load Data Lab
-- MAGIC 
-- MAGIC In this lab, you will extract and load raw data from JSON files into a Delta table.
-- MAGIC 
-- MAGIC ##### Objectives
-- MAGIC - Create an external table to extract data from JSON files
-- MAGIC - Create an empty Delta table with a provided schema
-- MAGIC - Insert records from an existing table into a Delta table
-- MAGIC - Use a CTAS statement to create a Delta table from files

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Run Setup
-- MAGIC 
-- MAGIC Run the following cell to configure variables and datasets for this lesson.

-- COMMAND ----------

-- MAGIC %run ../../Includes/setup

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Overview of the Data
-- MAGIC 
-- MAGIC We will work with a sample of raw Kafka data written as JSON files. Each file contains all records consumed during a 5-second interval, stored with the full Kafka schema as a multiple-record JSON file. The schema for the table:
-- MAGIC 
-- MAGIC | field  | type | description |
-- MAGIC | ------ | ---- | ----------- |
-- MAGIC | key    | BINARY | The `user_id` field is used as the key; this is a unique alphanumeric field that corresponds to session/cookie information |
-- MAGIC | offset | LONG | This is a unique value, monotonically increasing for each partition |
-- MAGIC | partition | INTEGER | Our current Kafka implementation uses only 2 partitions (0 and 1) |
-- MAGIC | timestamp | LONG    | This timestamp is recorded as milliseconds since epoch, and represents the time at which the producer appends a record to a partition |
-- MAGIC | topic | STRING | While the Kafka service hosts multiple topics, only those records from the `clickstream` topic are included here |
-- MAGIC | value | BINARY | This is the full data payload (to be discussed later), sent as JSON |

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC ## Extract Raw Events From JSON Files
-- MAGIC To load this data into Delta properly, we first need to extract the JSON data using the correct schema.
-- MAGIC 
-- MAGIC Create an external table against JSON files located at the filepath provided below. Name this table `events_json` and declare the schema above.

-- COMMAND ----------

-- ANSWER
CREATE TABLE IF NOT EXISTS events_json
(key BINARY, offset BIGINT, partition INT, timestamp BIGINT, topic STRING, value BINARY)
USING JSON OPTIONS (path = "${c.source}/events/events-kafka.json")

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **NOTE**: We'll use Python to run checks occasionally throughout the lab. The following cell will return as error with a message on what needs to change if you have not followed instructions. No output from cell execution means that you have completed this step.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("events_json"), "Table named `events_json` does not exist"
-- MAGIC assert spark.table("events_json").columns == ['key', 'offset', 'partition', 'timestamp', 'topic', 'value'], "Please name the columns in the order provided above"
-- MAGIC assert spark.table("events_json").dtypes == [('key', 'binary'), ('offset', 'int'), ('partition', 'bigint'), ('timestamp', 'bigint'), ('topic', 'string'), ('value', 'binary')], "Please make sure the column types are identical to those provided above"
-- MAGIC assert spark.table("events_json").count() == 45105, "The table should have 45105 records"

-- COMMAND ----------

-- MAGIC %md ## Insert Raw Events Into Delta Table
-- MAGIC Create a managed Delta table named `events_raw` using the same schema - we'll load the data extracted above into this empty table.

-- COMMAND ----------

-- ANSWER
CREATE OR REPLACE TABLE events_raw
(key BINARY, offset BIGINT, partition INT, timestamp BIGINT, topic STRING, value BINARY);

-- COMMAND ----------

-- MAGIC %md Run the cell below to confirm the table was created correctly.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("events_raw"), "Table named `events_json` does not exist"
-- MAGIC assert spark.table("events_raw").columns == ['key', 'offset', 'partition', 'timestamp', 'topic', 'value'], "Please name the columns in the order provided above"
-- MAGIC assert spark.table("events_raw").dtypes == [('key', 'binary'), ('offset', 'bigint'), ('partition', 'int'), ('timestamp', 'bigint'), ('topic', 'string'), ('value', 'binary')], "Please make sure the column types are identical to those provided above"
-- MAGIC assert spark.table("events_raw").count() == 0, "The table should have 0 records"

-- COMMAND ----------

-- MAGIC %md Once the extracted data and Delta table are ready, insert the JSON records from the `events_json` table into the new `events_raw` Delta table.

-- COMMAND ----------

-- ANSWER
INSERT INTO events_raw
SELECT * FROM events_json

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Manually review the table contents to ensure data was written as expected.

-- COMMAND ----------

-- ANSWER
SELECT * FROM events_raw

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to confirm the data has been loaded correctly.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("events_raw").count() == 45105, "The table should have 45105 records"
-- MAGIC assert set(row['timestamp'] for row in spark.table("events_raw").select("timestamp").limit(5).collect()) == {1593879300053, 1593879300372, 1593879300607, 1593879300739, 1593879300821}, "Make sure you have not modified the data provided"

-- COMMAND ----------

-- MAGIC %md ## Create Delta Table from a Query
-- MAGIC In addition to new events data, let's also load a small lookup table that provides product details that we'll use later in the course.
-- MAGIC Use a CTAS statement to create a managed Delta table named `item_lookup` that extracts data from the parquet directory provided below. 

-- COMMAND ----------

-- ANSWER
CREATE OR REPLACE TABLE item_lookup AS
SELECT * FROM parquet.`${c.source}/products/products.parquet`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to confirm the lookup table has been loaded correctly.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("item_lookup").count() == 12, "The table should have 12 records"
-- MAGIC assert set(row['item_id'] for row in spark.table("item_lookup").select("item_id").limit(5).collect()) == {'M_PREM_F', 'M_PREM_K', 'M_PREM_Q', 'M_PREM_T', 'M_STAN_F'}, "Make sure you have not modified the data provided"

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; 2022 Databricks, Inc. All rights reserved.<br/>
-- MAGIC Apache, Apache Spark, Spark and the Spark logo are trademarks of the <a href="https://www.apache.org/">Apache Software Foundation</a>.<br/>
-- MAGIC <br/>
-- MAGIC <a href="https://databricks.com/privacy-policy">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use">Terms of Use</a> | <a href="https://help.databricks.com/">Support</a>
