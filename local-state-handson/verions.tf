terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region  = "ap-northeast-1"
  profile = "lab-infra-shared"
  default_tags { // このproviderで管理される全リソースにデフォルトで付与されるtag
    tags = {
      Project   = "aws-tf-practice"
      ManagedBy = "terraform"
      Scope     = "local-state-handson"
    }
  }
}
