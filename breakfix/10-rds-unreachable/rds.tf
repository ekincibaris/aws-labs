resource "aws_db_subnet_group" "orders" {
  name        = "rds-lab-orders"
  description = "Private subnets of the data VPC"
  subnet_ids  = [for subnet in aws_subnet.data : subnet.id]
}

resource "aws_db_instance" "orders" {
  identifier     = "rds-lab-orders"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "orders"
  username                    = "orders_app"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.orders.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true
  deletion_protection        = false
  skip_final_snapshot        = true
}
