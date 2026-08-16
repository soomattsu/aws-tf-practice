# child moduleでは、root module（≒環境）毎に変動する引数値を入力変数として受け取る
variable "name_prefix" {
  description = "リソース名接頭辞"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnets" {
  description = "サブネット定義。typeはpublic/private"
  type = list(object({
    name = string
    az   = string
    cidr = string
    type = string
  }))
}
