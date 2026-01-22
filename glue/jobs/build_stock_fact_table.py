"""
Build Stock Fact Table

This Glue job transforms raw stock data into the fact_stock_daily_price table
with derived metrics and technical indicators.

KEY DATE LOGIC:
- Receives processing_date (e.g., 2026-01-20) from Step Functions
- Reads stock data from the previous trading day
"""

import sys
from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.window import Window

# =============================================================================
# INITIALIZATION & DATE CALCULATION
# =============================================================================

# Get job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'processing_date'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Get the processing date (already points to correct data)
processing_date = args['processing_date']  # Format: YYYY-MM-DD

print("="*80)
print("PROCESSING DATE")
print("="*80)
print(f"Processing Date: {processing_date}")
print(f"S3 Path: s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date={processing_date}/")
print("="*80)

# =============================================================================
# HELPER FUNCTION: SMART TABLE WRITE
# =============================================================================

def write_to_iceberg_table(df, table_name, partition_cols=None):
    """
    Intelligently writes to Iceberg table:
    - Creates table if it doesn't exist (first run)
    - Appends data if table exists (daily updates)
    
    Args:
        df: DataFrame to write
        table_name: Full table name (catalog.database.table)
        partition_cols: Column(s) to partition by (string or list)
    
    Returns:
        bool: True if table existed, False if newly created
    """
    # Check if table exists
    table_exists = spark.catalog.tableExists(table_name)
    
    print(f"Checking table {table_name}...")
    print(f"  Table exists: {table_exists}")
    
    writer = df.writeTo(table_name) \
        .tableProperty("format-version", "2") \
        .using("iceberg")
    
    # Add partitioning if specified
    if partition_cols:
        if isinstance(partition_cols, str):
            writer = writer.partitionedBy(partition_cols)
        else:
            writer = writer.partitionedBy(*partition_cols)
    
    # Use appropriate write mode
    if table_exists:
        print(f"  Action: Appending new data to existing table")
        writer.append()
        print(f"  ✓ Data appended successfully")
    else:
        print(f"  Action: Creating new table")
        writer.createOrReplace()
        print(f"  ✓ Table created successfully")
    
    return table_exists

# =============================================================================
# READ DATA (using previous day's date)
# =============================================================================
print("Reading raw data...")
# Read raw data
raw_df = spark.read.option("multiLine", "true").json(
    f"s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date={processing_date}/"
)
print(f"Raw data rows: {raw_df.count()}")

print("Raw data schema:")
raw_df.printSchema()

print("Sample raw data:")
raw_df.show(5, truncate=False)

print("Reading dimension tables...")
dim_stock = spark.table("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_stock")
dim_date = spark.table("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_date")
dim_exchange = spark.table("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_exchange")

# =============================================================================
# TRANSFORM RAW DATA TO FACT TABLE
# =============================================================================
print("Transforming raw data to fact table structure...")

fact_table = raw_df.select(
    to_date(from_unixtime(col("timestamp"))).alias("trade_date"),
    col("symbol"),
    col("exchange"),
    col("timestamp"),
    col("open").alias("open_price"),
    col("price").alias("close_price"),
    col("day_high").alias("high_price"),
    col("day_low").alias("low_price"),
    col("previous_close"),
    col("volume"),
    col("change").alias("change_amount"),
    col("change_percent").alias("change_percentage"),
    col("market_cap"),
    col("price_avg_50").alias("avg_price_50_day"),
    col("price_avg_200").alias("avg_price_200_day"),
    col("year_high"),
    col("year_low")
)

# =============================================================================
# CALCULATE DERIVED METRICS
# =============================================================================
print("Calculating derived metrics...")

fact_table = fact_table.withColumn(
    "intraday_range", 
    col("high_price") - col("low_price")
).withColumn(
    "volatility_indicator",
    (col("intraday_range") / col("open_price")) * 100
).withColumn(
    "distance_from_52w_high",
    ((col("year_high") - col("close_price")) / col("year_high")) * 100
).withColumn(
    "distance_from_52w_low",
    ((col("close_price") - col("year_low")) / col("year_low")) * 100
).withColumn(
    "relative_strength_50d",
    ((col("close_price") - col("avg_price_50_day")) / col("avg_price_50_day")) * 100
).withColumn(
    "relative_strength_200d",
    ((col("close_price") - col("avg_price_200_day")) / col("avg_price_200_day")) * 100
).withColumn(
    "created_at",
    current_timestamp()
)

print(f"Fact table rows after transformations: {fact_table.count()}")

# =============================================================================
# JOIN WITH DIMENSION TABLES
# =============================================================================
print("Joining with dimension tables...")

fact_final = fact_table \
    .join(dim_stock, fact_table.symbol == dim_stock.symbol, "left") \
    .join(dim_date, 
          to_date(fact_table.trade_date) == dim_date.date, "left") \
    .join(dim_exchange, 
          fact_table.exchange == dim_exchange.exchange_code, "left") \
    .select(
        dim_date.date_key,
        dim_stock.stock_key,
        dim_exchange.exchange_key,
        fact_table.timestamp,
        fact_table.open_price,
        fact_table.close_price,
        fact_table.high_price,
        fact_table.low_price,
        fact_table.previous_close,
        fact_table.volume,
        fact_table.change_amount,
        fact_table.change_percentage,
        fact_table.market_cap,
        fact_table.avg_price_50_day,
        fact_table.avg_price_200_day,
        fact_table.year_high,
        fact_table.year_low,
        fact_table.intraday_range,
        fact_table.volatility_indicator,
        fact_table.distance_from_52w_high,
        fact_table.distance_from_52w_low,
        fact_table.relative_strength_50d,
        fact_table.relative_strength_200d,
        fact_table.created_at
    )

print(f"Fact table rows after joins: {fact_final.count()}")

# =============================================================================
# DATA QUALITY CHECKS
# =============================================================================
print("Running data quality checks...")

# Check for nulls in critical columns
null_checks = fact_final.select([
    sum(col(c).isNull().cast("int")).alias(c)
    for c in ['date_key', 'stock_key', 'close_price', 'volume']
]).collect()[0]

for column, null_count in null_checks.asDict().items():
    if null_count > 0:
        print(f"WARNING: Found {null_count} null values in {column}")

# Check price ranges
price_stats = fact_final.agg(
    min('close_price').alias('min_price'),
    max('close_price').alias('max_price'),
    avg('close_price').alias('avg_price'),
    sum('volume').alias('total_volume')
).collect()[0]

print(f"Price statistics - Min: ${price_stats['min_price']:.2f}, "
      f"Max: ${price_stats['max_price']:.2f}, "
      f"Avg: ${price_stats['avg_price']:.2f}")
print(f"Total volume: {price_stats['total_volume']:,.0f}")

# =============================================================================
# WRITE TO ICEBERG TABLE (SMART MODE)
# =============================================================================
print("\n" + "="*80)
print("WRITING TO ICEBERG TABLE")
print("="*80)

table_existed = write_to_iceberg_table(
    df=fact_final,
    table_name="glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.fact_stock_daily_price",
    partition_cols="date_key"
)

print("="*80)

# =============================================================================
# JOB SUMMARY
# =============================================================================
print("\n" + "="*80)
print("FACT TABLE BUILD SUMMARY")
print("="*80)
print(f"Processing Date: {processing_date}")
# print(f"Data Date: {data_date}")
print(f"Records Processed: {fact_final.count()}")
print(f"Write Mode: {'Append' if table_existed else 'Create'}")
print(f"Price Range: ${price_stats['min_price']:.2f} - ${price_stats['max_price']:.2f}")
print(f"Total Volume: {price_stats['total_volume']:,.0f}")
# print(f"Date Key in Warehouse: {data_date.replace('-', '')}")
print("="*80)

job.commit()
print("Job completed successfully!")
