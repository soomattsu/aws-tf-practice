resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-aurora"
  subnet_ids = var.subnet_ids
}

# ingressルールは、アクセスしたい呼び出し側が自分で渡す
resource "aws_security_group" "main" {
  name        = "${var.name_prefix}-aurora"
  description = "SG for Aurora MySQL, rules are owned by consumers"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-aurora-sg"
  }
}

# RDSのDBクラスタ + Aurora用の共有ストレージ層を作成（後者はengineにAuroraを指定したことで作成される）
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"

  database_name   = var.database_name
  master_username = "admin"

  # master user passwordをRDS管理下に置き、Secrets Managerで自動生成＆格納
  # -> tfstateにはsecretのARNのみが記録され、パスワードは含まれない
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.main.id]
  port                   = var.port

  # KMSのRDS用デフォルトデータキーで、データ保存時暗号化を実施
  storage_encrypted = true

  # 学習用のため、バックアップ最小化 ＆ destroy執行許可
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}

# AuroraのDBクラスタに参加する、compute層のDBインスタンスを作成
resource "aws_rds_cluster_instance" "main" {
  identifier          = "${var.name_prefix}-aurora-1"
  cluster_identifier  = aws_rds_cluster.main.id
  instance_class      = var.instance_class
  engine              = aws_rds_cluster.main.engine
  engine_version      = aws_rds_cluster.main.engine_version
  publicly_accessible = false
}
