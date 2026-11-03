# Hints · 01 Shop returns 502 Bad Gateway

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

The load balancer generated the 502 itself, not the shop. It means the load balancer couldn't get a usable answer from a target. Start with what the load balancer thinks of its targets, and look at the `AWS/ApplicationELB` metrics about connections to them.

</details>

<details>
<summary>Hint 2</summary>

Both targets are unhealthy, with the reason **Health checks failed**. When every target is unhealthy, an ALB still forwards requests to all of them ("fail open"). That's why users get 502 and not 503.

Open a Session Manager shell on one of the web servers and compare:

- the port the shop actually listens on (`sudo ss -tlnp`), and
- the port the load balancer sends traffic and health checks to.

</details>

<details>
<summary>Hint 3</summary>

A target group sends traffic, and by default its health checks (`traffic-port`), to the port each target is **registered** on. The targets are registered on port 80, but the shop listens on 8080. Nothing listens on 80, so the instance answers every connection with a TCP reset, and the load balancer turns that into a 502. Make the registered port match the application.

</details>
