variable "name_prefix" {
  description = "common prefix for resource name"
  type        = string
  default     = "tf-local-handson"
}

variable "bucket_suffix" {
  description = "suffix for securing uniqueness of S3 bucket"
  type        = string
}
