terraform {
  required_version = ">= 1.17"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project   = "aws-labs"
      Lab       = "breakfix/07-eventbridge-rule-not-firing"
      ManagedBy = "terraform"
    }
  }
}
