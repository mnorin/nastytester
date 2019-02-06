#!/bin/bash

rm -rf ./public/*
hugo
cd public
aws s3 sync "." "s3://nasty-tester" --delete
