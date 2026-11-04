"""Report viewer: returns the content of one report from the reports bucket."""

import os

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["REPORTS_BUCKET"]


def handler(event, context):
    key = (event or {}).get("key", "reports/2026-10.csv")

    response = s3.get_object(Bucket=BUCKET, Key=key)
    content = response["Body"].read().decode()
    print(f"served s3://{BUCKET}/{key}")
    return {"key": key, "content": content}
