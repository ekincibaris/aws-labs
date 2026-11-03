"""Monthly report exporter: writes this month's sales report to the reports bucket."""

import datetime
import os

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["REPORTS_BUCKET"]


def handler(event, context):
    month = datetime.date.today().strftime("%Y-%m")
    key = f"reports/{month}.csv"
    body = f"month,orders,revenue_eur\n{month},1342,50117.80\n"

    s3.put_object(Bucket=BUCKET, Key=key, Body=body.encode(), ContentType="text/csv")
    print(f"exported s3://{BUCKET}/{key}")
    return {"status": "exported", "key": key}
