"""
Build Stock Aggregation Tables

This Glue job creates aggregation tables for analytics:
- agg_stock_weekly_metrics: Weekly performance metrics
- agg_stock_monthly_metrics: Monthly performance metrics
- agg_sector_performance: Sector-level aggregations
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.window import Window

# Get job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

job.init(args['JOB_NAME'], args)

print("Starting aggregation tables build job...")

# =============================================================================
# READ DATA
# =============================================================================
print("Reading fact and dimension tables...")
fact_df = spark.table("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.fact_stock_daily_price")
dim_stock = spark.table("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_stock")
dim_date = spark.table("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.dim_date")

print(f"Fact table rows: {fact_df.count()}")

# =============================================================================
# AGG_STOCK_WEEKLY_METRICS
# =============================================================================
print("Building agg_stock_weekly_metrics...")

weekly_agg = fact_df \
    .join(dim_date, fact_df.date_key == dim_date.date_key) \
    .join(dim_stock, fact_df.stock_key == dim_stock.stock_key) \
    .groupBy(
        dim_date.year,
        dim_date.week,
        dim_stock.symbol,
        dim_stock.company_name
    ) \
    .agg(
        first("open_price").alias("week_open"),
        last("close_price").alias("week_close"),
        max("high_price").alias("week_high"),
        min("low_price").alias("week_low"),
        sum("volume").alias("total_volume"),
        avg("close_price").alias("avg_price"),
        stddev("close_price").alias("price_std_dev"),
        avg("volatility_indicator").alias("avg_volatility"),
        ((last("close_price") - first("open_price")) / first("open_price") * 100).alias("weekly_return_pct")
    )

print(f"Weekly aggregation rows: {weekly_agg.count()}")

print("Writing agg_stock_weekly_metrics to Iceberg...")
weekly_agg.writeTo("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.agg_stock_weekly_metrics") \
    .tableProperty("format-version", "2") \
    .partitionedBy("year", "week") \
    .using("iceberg") \
    .createOrReplace()

print("✓ agg_stock_weekly_metrics created successfully")

# =============================================================================
# AGG_STOCK_MONTHLY_METRICS
# =============================================================================
print("Building agg_stock_monthly_metrics...")

monthly_agg = fact_df \
    .join(dim_date, fact_df.date_key == dim_date.date_key) \
    .join(dim_stock, fact_df.stock_key == dim_stock.stock_key) \
    .groupBy(
        dim_date.year,
        dim_date.month,
        dim_stock.symbol,
        dim_stock.company_name,
        dim_stock.sector
    ) \
    .agg(
        first("open_price").alias("month_open"),
        last("close_price").alias("month_close"),
        max("high_price").alias("month_high"),
        min("low_price").alias("month_low"),
        sum("volume").alias("total_volume"),
        avg("close_price").alias("avg_price"),
        avg("market_cap").alias("avg_market_cap"),
        stddev("close_price").alias("price_volatility"),
        ((last("close_price") - first("open_price")) / first("open_price") * 100).alias("monthly_return_pct"),
        max("distance_from_52w_high").alias("max_distance_from_high"),
        min("distance_from_52w_low").alias("min_distance_from_low")
    )

print(f"Monthly aggregation rows: {monthly_agg.count()}")

print("Writing agg_stock_monthly_metrics to Iceberg...")
monthly_agg.writeTo("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.agg_stock_monthly_metrics") \
    .tableProperty("format-version", "2") \
    .partitionedBy("year", "month") \
    .using("iceberg") \
    .createOrReplace()

print("✓ agg_stock_monthly_metrics created successfully")

# =============================================================================
# AGG_SECTOR_PERFORMANCE
# =============================================================================
print("Building agg_sector_performance...")

sector_performance = fact_df \
    .join(dim_stock, fact_df.stock_key == dim_stock.stock_key) \
    .join(dim_date, fact_df.date_key == dim_date.date_key) \
    .groupBy(
        dim_date.date,
        dim_stock.sector
    ) \
    .agg(
        avg("change_percentage").alias("avg_sector_change"),
        sum("volume").alias("total_sector_volume"),
        avg("market_cap").alias("avg_sector_market_cap"),
        count("*").alias("num_stocks"),
        stddev("change_percentage").alias("sector_volatility")
    )

print(f"Sector performance rows: {sector_performance.count()}")

print("Writing agg_sector_performance to Iceberg...")
sector_performance.writeTo("glue_catalog.nasdaq-equity-batch-pipeline-warehouse_dev.agg_sector_performance") \
    .tableProperty("format-version", "2") \
    .partitionedBy("date") \
    .using("iceberg") \
    .createOrReplace()

print("✓ agg_sector_performance created successfully")

# =============================================================================
# JOB SUMMARY
# =============================================================================
print("\n" + "="*80)
print("AGGREGATION TABLES BUILD SUMMARY")
print("="*80)
print(f"✓ agg_stock_weekly_metrics: {weekly_agg.count()} rows")
print(f"✓ agg_stock_monthly_metrics: {monthly_agg.count()} rows")
print(f"✓ agg_sector_performance: {sector_performance.count()} rows")
print("="*80)

job.commit()
print("Job completed successfully!")
