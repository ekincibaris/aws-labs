terraform {
  required_version = ">= 1.17"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project   = "aws-labs"
      Lab       = "breakfix/01-alb-502-bad-gateway"
      ManagedBy = "terraform"
    }
  }
}
