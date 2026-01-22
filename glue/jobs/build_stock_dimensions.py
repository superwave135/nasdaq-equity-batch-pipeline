"""
Build Stock Dimension Tables

This Glue job creates dimension tables for the stock data warehouse nasdaq-equity-batch-pipeline-warehouse_dev:
- dim_stock: Stock metadata
- dim_date: Date dimension with trading calendar
- dim_exchange: Exchange information
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime, timedelta

# Get job parameters

# Fixed - Add 'processing_date' to the arguments
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'processing_date'])
processing_date = args['processing_date']

print(f"Processing date: {processing_date}")  # Add this for debugging

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

job.init(args['JOB_NAME'], args)

print("Starting dimension table build job...")
print(f"Processing date: {processing_date}")

# =============================================================================
# READ RAW DATA
# =============================================================================
print("Reading raw stock data from S3...")
# FIXED: Add multiLine=true to read JSON array format
raw_df = spark.read.option("multiLine", "true").json("s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date=*/")
print(f"Raw data rows: {raw_df.count()}")

# Print schema for verification
print("Raw data schema:")
raw_df.printSchema()

# Show sample data
print("Sample raw data:")
raw_df.show(5, truncate=False)

# =============================================================================
# DIM_STOCK - Stock dimension table
# =============================================================================
print("Building dim_stock dimension table...")

dim_stock = raw_df.select(
    monotonically_increasing_id().alias("stock_key"),
    col("symbol"),
    col("name").alias("company_name"),
    col("exchange"),
    # Use market_cap to determine tier
    when(col("market_cap") > 1000000000000, "Large Cap")
     .when(col("market_cap") > 10000000000, "Mid Cap")
     .otherwise("Small Cap").alias("market_cap_tier"),
    # Sector and industry would come from enrichment - using placeholders
    lit("Technology").alias("sector"),
    lit("Software").alias("industry"),
    lit(processing_date).alias("first_seen_date"),
    lit(processing_date).alias("last_seen_date"),
    lit(True).alias("is_active")
).dropDuplicates(["symbol"])

print(f"dim_stock rows: {dim_stock.count()}")

# Show sample dimension data
print("Sample dim_stock data:")
dim_stock.show(5, truncate=False)

# Write to Iceberg table
print("Writing dim_stock to Iceberg...")
dim_stock.writeTo("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_stock") \
    .tableProperty("format-version", "2") \
    .using("iceberg") \
    .createOrReplace()

print("✓ dim_stock created successfully")

# =============================================================================
# DIM_DATE - Date dimension table
# =============================================================================
print("Building dim_date dimension table...")

# Generate date range (5 years: 2020-2026)
start_date = datetime(2020, 1, 1)
end_date = datetime(2026, 12, 31)
date_range = [(start_date + timedelta(days=x)) for x in range((end_date - start_date).days + 1)]

dim_date_data = [
    (
        int(d.strftime('%Y%m%d')),  # date_key: YYYYMMDD
        d.date(),
        d.year,
        (d.month - 1) // 3 + 1,  # quarter
        d.month,
        d.isocalendar()[1],  # week
        d.strftime('%A'),  # day_of_week
        d.weekday() < 5  # is_trading_day (Mon-Fri, simplified)
    )
    for d in date_range
]

dim_date_schema = StructType([
    StructField("date_key", IntegerType(), False),
    StructField("date", DateType(), False),
    StructField("year", IntegerType(), False),
    StructField("quarter", IntegerType(), False),
    StructField("month", IntegerType(), False),
    StructField("week", IntegerType(), False),
    StructField("day_of_week", StringType(), False),
    StructField("is_trading_day", BooleanType(), False)
])

dim_date = spark.createDataFrame(dim_date_data, dim_date_schema)

print(f"dim_date rows: {dim_date.count()}")

# Write to Iceberg table
print("Writing dim_date to Iceberg...")
dim_date.writeTo("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_date") \
    .tableProperty("format-version", "2") \
    .using("iceberg") \
    .createOrReplace()

print("✓ dim_date created successfully")

# =============================================================================
# DIM_EXCHANGE - Exchange dimension table
# =============================================================================
print("Building dim_exchange dimension table...")

dim_exchange = spark.createDataFrame([
    (1, "NASDAQ", "NASDAQ Stock Market", "USA", "America/New_York"),
    (2, "NYSE", "New York Stock Exchange", "USA", "America/New_York"),
    (3, "AMEX", "American Stock Exchange", "USA", "America/New_York")
], ["exchange_key", "exchange_code", "exchange_name", "country", "timezone"])

print(f"dim_exchange rows: {dim_exchange.count()}")

# Write to Iceberg table
print("Writing dim_exchange to Iceberg...")
dim_exchange.writeTo("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_exchange") \
    .tableProperty("format-version", "2") \
    .using("iceberg") \
    .createOrReplace()

print("✓ dim_exchange created successfully")

# =============================================================================
# JOB SUMMARY
# =============================================================================
print("\n" + "="*80)
print("DIMENSION TABLES BUILD SUMMARY")
print("="*80)
print(f"✓ dim_stock: {dim_stock.count()} rows")
print(f"✓ dim_date: {dim_date.count()} rows")
print(f"✓ dim_exchange: {dim_exchange.count()} rows")
print("="*80)

job.commit()
print("Job completed successfully!")
