#!/bin/bash

rm -rf ./public/*
hugo
cd public

# Copy files to S3 bucket
aws s3 sync "." "s3://nasty-tester" --delete

# Invalidate distribution
# E2AXR8IBYZ1SM6
aws cloudfront create-invalidation --distribution-id E2AXR8IBYZ1SM6 --paths '/posts/*.html' '/*.html'
