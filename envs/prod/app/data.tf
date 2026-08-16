data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket
    key     = "envs/prod/network/terraform.tfstate"
    region  = var.region
    profile = var.profile
  }
}

locals {
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}
