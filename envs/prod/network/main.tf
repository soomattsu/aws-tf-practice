data "aws_caller_identity" "current" {}

module "network" {
  source = "../../../modules/network"

  name_prefix = "tf-practice"
  vpc_cidr    = "10.0.0.0/16"
  subnets = [
    { "name" : "pub_c", "az" : "ap-northeast-1c", "cidr" : "10.0.0.0/24", "type" : "public" },
    { "name" : "pub_d", "az" : "ap-northeast-1d", "cidr" : "10.0.1.0/24", "type" : "public" },
    { "name" : "priv_c", "az" : "ap-northeast-1c", "cidr" : "10.0.10.0/24", "type" : "private" },
    { "name" : "priv_d", "az" : "ap-northeast-1d", "cidr" : "10.0.11.0/24", "type" : "private" }
  ]
}
