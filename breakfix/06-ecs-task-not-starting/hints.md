# Hints · 06 ECS service never reaches Running

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

A task that disappears after a few seconds always leaves a reason behind. An empty log group means the container never started, so there is nothing to find in the application logs. Look at the **stopped tasks** and at the service's **Events** instead.

</details>

<details>
<summary>Hint 2</summary>

The stopped reason starts with `ResourceInitializationError` and contains an `AccessDeniedException` for `ssm:GetParameters`. Read carefully **which role** the error message names. Then check which role actually has the policy that allows reading the parameter.

</details>

<details>
<summary>Hint 3</summary>

An ECS task uses two roles:

- The **task execution role** is used by ECS and Fargate to *start* the task: pull the image, create the log stream, and fetch the values for `secrets`.
- The **task role** is used by your *application code* once the container is running.

Values in the task definition's `secrets` section are fetched before the container starts, so the execution role needs `ssm:GetParameters` on that parameter.

</details>
