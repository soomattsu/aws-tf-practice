variable "profile" {
  description = "profile to init AWS provider"
  type        = string
}

variable "region" {
  description = "region where AWS operations will take place"
  type        = string
  default     = "ap-northeast-1"
}
