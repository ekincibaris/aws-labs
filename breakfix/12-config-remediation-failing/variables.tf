variable "create_config_recorder" {
  description = "Create an AWS Config recorder and delivery channel. Set to false if your account already has a recorder in eu-central-1 (only one is allowed per Region); it must record AWS::EC2::SecurityGroup."
  type        = bool
  default     = true
}
