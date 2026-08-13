terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key = "bootstrap/state-backend/terraform.tfstate"
    # other args are inserted by backend.hcl
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
  default_tags {
    tags = {
      Project   = "aws-tf-practice"
      ManagedBy = "terraform"
      Layer     = "bootstrap"
    }
  }
}
