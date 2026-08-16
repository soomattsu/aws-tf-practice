# movedブロック：デプロイ済みリソースを変更せずに、TerraformのState上のリソース名を変更する
# - applyするとstateが書き換わり、リソース名変更が適用される
# - move完了後はファイルごと削除してOK（moved.tfがある状態でコミットを残しておくとよい）
# module化やループを使って、Terraform側のリソース作成コードをリファクタリングした際に有効

moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_subnet.main
  to   = module.network.aws_subnet.main
}

moved {
  from = aws_internet_gateway.main
  to   = module.network.aws_internet_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}

moved {
  from = aws_route_table_association.public
  to   = module.network.aws_route_table_association.public
}

moved {
  from = aws_route_table.private
  to   = module.network.aws_route_table.private
}

moved {
  from = aws_route_table_association.private
  to   = module.network.aws_route_table_association.private
}

moved {
  from = aws_nat_gateway.main
  to   = module.network.aws_nat_gateway.main
}

moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}
