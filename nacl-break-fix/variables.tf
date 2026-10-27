variable "my_ip_cidr" {
  description = "My public IPv4 address in CIDR form, allowed to SSH in"
  type        = string
  sensitive   = true
}
