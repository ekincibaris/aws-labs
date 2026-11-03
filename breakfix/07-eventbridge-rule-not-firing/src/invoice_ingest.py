"""invoice-ingest: registers every new invoice that lands in incoming/."""

import json


def handler(event, context):
    detail = (event or {}).get("detail", {})
    invoice = {
        "bucket": detail.get("bucket", {}).get("name"),
        "key": detail.get("object", {}).get("key"),
        "size": detail.get("object", {}).get("size"),
    }
    print(json.dumps({"message": "invoice registered", **invoice}))
    return {"status": "registered", **invoice}
