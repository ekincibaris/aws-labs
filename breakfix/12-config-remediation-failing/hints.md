# Hints · 12 Config flags open SSH, but auto-remediation never fixes it

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

AWS Config doesn't change security groups itself. Its remediation **starts something else** that does the work. Find out what was started, and what happened to it.

</details>

<details>
<summary>Hint 2</summary>

The remediation status in Config is **failed**. Open Systems Manager → **Automation** → **Executions**: the runbook `AWS-DisableIncomingSSHOnPort22` has run several times and failed every time, before it changed anything. Read the failure message. Then look at the IAM role the runbook was told to use (its `AutomationAssumeRole` parameter), and specifically at **who is allowed to assume it**.

</details>

<details>
<summary>Hint 3</summary>

Config only starts the runbook. **Systems Manager Automation** is the service that assumes the `AutomationAssumeRole`. That role's trust policy must allow `ssm.amazonaws.com`, but this one only trusts `config.amazonaws.com`. Fix the trust policy, then run the remediation again from the Config console (**Remediate**) or with `aws configservice start-remediation-execution`.

</details>
