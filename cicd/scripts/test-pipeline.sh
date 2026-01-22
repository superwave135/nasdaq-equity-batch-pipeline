#!/bin/bash
set -e

# ============================================================================
# Pipeline Integration Test Script - NASDAQ Equity Batch Pipeline
# ============================================================================
# Purpose: Run end-to-end integration tests for the pipeline
# Usage: ./test-pipeline.sh [environment]
# ============================================================================

echo "============================================"
echo "🧪 Pipeline Integration Test Script"
echo "============================================"

# Configuration
ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
LAMBDA_FUNCTION="nasdaq-equity-batch-pipeline-extractor-$ENVIRONMENT"
S3_BUCKET="nasdaq-equity-batch-pipeline-$ENVIRONMENT"
GLUE_DATABASE="nasdaq-equity-batch-pipeline-warehouse_$ENVIRONMENT"

echo "Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  Lambda Function: $LAMBDA_FUNCTION"
echo "  S3 Bucket: $S3_BUCKET"
echo "  Glue Database: $GLUE_DATABASE"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test result function
test_result() {
    if [ $1 -eq 0 ]; then
        echo "  ✅ PASS: $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ❌ FAIL: $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo ""
echo "============================================"
echo "🔍 Infrastructure Tests"
echo "============================================"

# Test 1: Lambda function exists
echo ""
echo "Test 1: Lambda function exists..."
aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    > /dev/null 2>&1
test_result $? "Lambda function exists"

# Test 2: S3 bucket exists
echo ""
echo "Test 2: S3 bucket exists..."
aws s3 ls "s3://$S3_BUCKET" \
    --region "$AWS_REGION" \
    > /dev/null 2>&1
test_result $? "S3 bucket exists"

# Test 3: Glue database exists
echo ""
echo "Test 3: Glue database exists..."
aws glue get-database \
    --name "$GLUE_DATABASE" \
    --region "$AWS_REGION" \
    > /dev/null 2>&1
test_result $? "Glue database exists"

# Test 4: Glue scripts in S3
echo ""
echo "Test 4: Glue scripts in S3..."
SCRIPT_COUNT=$(aws s3 ls "s3://$S3_BUCKET/glue-scripts/" \
    --region "$AWS_REGION" \
    | grep "\.py$" \
    | wc -l)
if [ "$SCRIPT_COUNT" -gt 0 ]; then
    test_result 0 "Found $SCRIPT_COUNT Glue scripts in S3"
else
    test_result 1 "No Glue scripts found in S3"
fi

echo ""
echo "============================================"
echo "🚀 Lambda Function Tests"
echo "============================================"

# Test 5: Lambda function invocation
echo ""
echo "Test 5: Lambda function test invocation..."
TEST_EVENT='{
  "test": true,
  "symbols": ["AAPL"],
  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

echo "Test event:"
echo "$TEST_EVENT" | jq '.'

aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION" \
    --payload "$TEST_EVENT" \
    --region "$AWS_REGION" \
    /tmp/lambda-test-response.json \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Lambda response:"
    cat /tmp/lambda-test-response.json | jq '.'
    
    # Check if response is valid JSON
    if jq -e . /tmp/lambda-test-response.json > /dev/null 2>&1; then
        test_result 0 "Lambda function invocation successful"
    else
        test_result 1 "Lambda response is not valid JSON"
    fi
    rm /tmp/lambda-test-response.json
else
    test_result 1 "Lambda function invocation failed"
fi

echo ""
echo "============================================"
echo "📊 S3 Data Tests"
echo "============================================"

# Test 6: Raw data in S3
echo ""
echo "Test 6: Raw data in S3..."
RAW_DATA_COUNT=$(aws s3 ls "s3://$S3_BUCKET/raw/" \
    --region "$AWS_REGION" \
    --recursive \
    | wc -l)

if [ "$RAW_DATA_COUNT" -gt 0 ]; then
    echo "  Found $RAW_DATA_COUNT raw data files"
    echo "  Latest files:"
    aws s3 ls "s3://$S3_BUCKET/raw/" \
        --region "$AWS_REGION" \
        --recursive \
        --human-readable \
        | tail -5
    test_result 0 "Raw data exists in S3"
else
    echo "  ⚠️  No raw data found (pipeline may not have run yet)"
    test_result 1 "No raw data in S3"
fi

# Test 7: Processed data in S3
echo ""
echo "Test 7: Processed data in S3..."
PROCESSED_DATA_COUNT=$(aws s3 ls "s3://$S3_BUCKET/processed/" \
    --region "$AWS_REGION" \
    --recursive \
    | wc -l)

if [ "$PROCESSED_DATA_COUNT" -gt 0 ]; then
    echo "  Found $PROCESSED_DATA_COUNT processed data files"
    test_result 0 "Processed data exists in S3"
else
    echo "  ⚠️  No processed data found (Glue jobs may not have run yet)"
    test_result 1 "No processed data in S3"
fi

echo ""
echo "============================================"
echo "🗄️ Glue Catalog Tests"
echo "============================================"

# Test 8: Glue tables exist
echo ""
echo "Test 8: Glue tables exist..."
TABLE_LIST=$(aws glue get-tables \
    --database-name "$GLUE_DATABASE" \
    --region "$AWS_REGION" \
    --query 'TableList[].Name' \
    --output text 2>/dev/null || echo "")

if [ -n "$TABLE_LIST" ]; then
    TABLE_COUNT=$(echo "$TABLE_LIST" | wc -w)
    echo "  Found $TABLE_COUNT table(s):"
    echo "$TABLE_LIST" | tr '\t' '\n' | sed 's/^/    - /'
    test_result 0 "Glue tables exist"
else
    echo "  ⚠️  No tables found (pipeline may not have created tables yet)"
    test_result 1 "No Glue tables found"
fi

echo ""
echo "============================================"
echo "📋 Test Summary"
echo "============================================"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
PASS_RATE=$(echo "scale=1; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc)

echo ""
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $TESTS_PASSED ✅"
echo "Failed: $TESTS_FAILED ❌"
echo "Pass Rate: $PASS_RATE%"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo "============================================"
    echo "🎉 All tests passed!"
    echo "============================================"
    exit 0
else
    echo "============================================"
    echo "⚠️  Some tests failed"
    echo "============================================"
    echo ""
    echo "Next steps:"
    echo "1. Review failed tests above"
    echo "2. Check CloudWatch logs for errors"
    echo "3. Verify pipeline has run at least once"
    echo "4. Re-run tests after fixing issues"
    exit 1
fi
