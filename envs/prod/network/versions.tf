terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    # terraform init will accept backend.hcl
    key = "envs/prod/network/terraform.tfstate"
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile

  assume_role {
    role_arn     = var.terraform_exec_role_arn
    session_name = "terraform-prod-network"
  }

  default_tags {
    tags = {
      Project   = "aws-tf-practice"
      ManagedBy = "terraform"
      Layer     = "envs/prod"
    }
  }
}
