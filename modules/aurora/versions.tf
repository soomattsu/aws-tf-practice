# provider設定・stateを持つのはroot module（apply実行モジュール）だけ
# -> 再利用されるchild moduleはこれらに関与しないので、provider, backendは不要
terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
