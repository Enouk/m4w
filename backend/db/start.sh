#!/usr/bin/env bash

docker run -d --name m4w-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=m4w_dev \
  -p 5432:5432 \
  -v "$PWD/data:/var/lib/postgresql" \
  -d postgres:18