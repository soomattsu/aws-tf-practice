data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket
    key     = "envs/prod/network/terraform.tfstate"
    region  = var.region
    profile = var.profile
  }
}

module "aurora" {
  source = "../../../modules/aurora"

  name_prefix    = "tf-practice"
  vpc_id         = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids     = data.terraform_remote_state.network.outputs.private_subnet_ids
  database_name  = "appdb"
  instance_class = "db.t4g.medium"
}
