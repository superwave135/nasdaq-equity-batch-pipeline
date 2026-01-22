#!/bin/bash

# ============================================================================
# Lambda Function Packaging Script
# ============================================================================

set -e  # Exit on any error

# Get absolute path to project root
PROJECT_ROOT="$(pwd)"

# Configuration
LAMBDA_DIR="lambda/stock_extractor"
BUILD_DIR="build"
OUTPUT_ZIP="lambda-function.zip"
TEMP_DIR=$(mktemp -d)

echo "============================================"
echo "Packaging Lambda Function"
echo "============================================"
echo "Project root: ${PROJECT_ROOT}"
echo "Lambda directory: ${LAMBDA_DIR}"
echo "Temp directory: ${TEMP_DIR}"
echo ""

# Ensure build directory exists
mkdir -p "${PROJECT_ROOT}/${BUILD_DIR}/lambda"

# Copy Lambda code to temp directory
echo "Copying Lambda code..."
cp -r ${PROJECT_ROOT}/${LAMBDA_DIR}/* ${TEMP_DIR}/

# Install dependencies
echo "Installing Python dependencies..."
cd ${TEMP_DIR}

if [ -f requirements.txt ]; then
    pip install -r requirements.txt -t . --upgrade --quiet
    echo "  Dependencies installed"
else
    echo "  No requirements.txt found"
fi

# Remove unnecessary files
echo "Removing unnecessary files..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete
find . -type f -name "*.pyo" -delete

echo "  Cleanup complete"

# Create zip file
echo "Creating zip file..."
zip -r9 ${OUTPUT_ZIP} . -x "*.git*" "*.pyc" "*__pycache__*" -q

# Move to final location
mv ${OUTPUT_ZIP} ${PROJECT_ROOT}/${BUILD_DIR}/lambda/${OUTPUT_ZIP}

echo "  Zip file created"

# Return to project root
cd ${PROJECT_ROOT}

# Generate checksums
echo "Generating checksums..."
MD5=$(md5sum ${BUILD_DIR}/lambda/${OUTPUT_ZIP} | awk '{print $1}')
SHA256=$(sha256sum ${BUILD_DIR}/lambda/${OUTPUT_ZIP} | awk '{print $1}')

# Get file size
SIZE=$(du -h ${BUILD_DIR}/lambda/${OUTPUT_ZIP} | cut -f1)

# Cleanup temp directory
rm -rf ${TEMP_DIR}

echo ""
echo "============================================"
echo "Packaging Complete!"
echo "============================================"
echo "Output file: ${BUILD_DIR}/lambda/${OUTPUT_ZIP}"
echo "File size: ${SIZE}"
echo "MD5: ${MD5}"
echo "SHA256: ${SHA256}"
echo "============================================"
echo "Ready for deployment!"
echo "============================================"
