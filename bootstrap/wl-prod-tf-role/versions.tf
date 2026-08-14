terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    # 共通のbackend s3を使うので、他の引数はbackend.hclから挿入
    key = "bootstrap/wl-prod-tf-role/terraform.tfstate"
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
