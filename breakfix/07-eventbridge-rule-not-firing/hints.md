# Hints · 07 New invoices aren't processed

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

Split the pipeline into hops: **S3 → event bus → rule → target (Lambda)**. Find the first hop where nothing arrives. The rule's CloudWatch metrics (namespace `AWS/Events`) tell you whether it ever matched an event, and whether it tried to invoke its target.

</details>

<details>
<summary>Hint 2</summary>

`MatchedEvents` has no datapoints at all. So the target and its permission aren't the problem yet: the rule has never seen a matching event.

Test the rule's pattern against a sample S3 **Object Created** event in the EventBridge **Sandbox**, or with `aws events test-event-pattern`, using your bucket name and an `incoming/` key. If the pattern matches the sample, then the events aren't reaching the event bus in the first place.

</details>

<details>
<summary>Hint 3</summary>

S3 doesn't send events to EventBridge by default. It's a per-bucket switch, separate from the classic event notifications to SNS, SQS or Lambda: **Properties → Event notifications → Amazon EventBridge**. A rebuilt bucket doesn't carry this setting over.

</details>
