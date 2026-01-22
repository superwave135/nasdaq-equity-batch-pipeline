#!/bin/bash
aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1