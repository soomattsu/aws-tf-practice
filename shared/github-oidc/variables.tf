variable "profile" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "github_oidc_sub" {
  type    = string
  default = "repo:soomattsu@39475314/http-server-practice@1319068791"
}
