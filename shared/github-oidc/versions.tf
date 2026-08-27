terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      version = "~> 6.0"
      source  = "hashicorp/aws"
    }
  }

  backend "s3" {
    # other args are inserted by backend.hcl
    key = "shared/github-oidc/terraform.tfstate"
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region

  default_tags {
    tags = {
      Project   = "aws-tf-practice"
      ManagedBy = "terraform"
      Layer     = "shared"
    }
  }
}
