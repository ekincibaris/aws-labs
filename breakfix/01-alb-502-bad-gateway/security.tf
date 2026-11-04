resource "aws_security_group" "alb" {
  name        = "alb-lab-alb-sg"
  description = "HTTP from the internet to the load balancer"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "alb-lab-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  description                  = "All traffic to the web servers"
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "-1"
}

resource "aws_security_group" "web" {
  name        = "alb-lab-web-sg"
  description = "Web servers accept traffic from the load balancer only"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "alb-lab-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "All traffic from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "web_all_out" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
