# Prodアカウント上のリソースを、他アカウントから実行されたTerraformで操作するためのロールを作成する

# 設計判断（ベストプラクティス）
# **マルチアカウントのリソース操作では「操作対象アカウントをprofileなどで直接指定する」代わりに「特定アカウントのcredentialで認証した後、assume_roleで各アカウントのTerraform用ロールへ切り替えながら使う」べき**
# - Terraform実行の起点となるcredential/アカウントを一元化するため（ここではinfra-shared）
#   - クロスアカウントが適切に設定されていれば、Terraform利用のために考慮するcredentialは入口分の1つのみに限定できる
# - 人間の権限・Terraformの権限を安全に分離するため
# 　　- SSOログイン用profileを指定すると、Terraformが行使する権限が、SSOロールの権限（人間用）と同一になる
#   - 各アカウントにtf専用IAMユーザーを作ることで権限分離はできるが、管理コスト＆セキュリティ的に望ましくない
# - CloudTrail(監査サービス)でリソース操作を追跡可能にするため
#   - 「誰が、いつ、どの経路（Terraform/手作業）でリソース変更を行ったか」を漏れなく追跡できるのはassume_roleの場合だけ
# - GitHub Actionsなど、CI/CDツールとのOIDCでの統合が簡単

# 備考
# - AWSで、アカウントAのプリンシパル（user/role）によるアカウントBのリソース操作を許可する(opt-in)には、2つの手段しか無い
#   - resource based policy: 一部のサービスにしか設定できない
#   - IAMロール（+適切な信頼ポリシー）: 全サービス共通。TerraformでIaCするユースケースは、実質こっち一択
#     - BでIAMロールと信頼ポリシーを定義し、AでそのロールをAssumeRoleする形
# - "クロスアカウントAssumeRole"の実現には、双方向のAllowが必要
#   - Assumeする側：identity-based policyで、sts:AssumeRoleアクションが許可されている
#   - Assumeされる側：ロールのtrust policyで、Assumeする側をPrincipalとして許可している


# 「信頼するアカウントのSSO由来ロールのみ、このロールをAssumeできる」というtrust policy用のJSONを構成
# 2つの条件の論理積で定義する
# - 1. 「trusted_account_id側のIAMでAssumeRoleアクションを許可されている全プリンシパル」
# - 2. 「trusted_account_id側のSSO由来ロールにマッチするプリンシパル」
# (Principalフィールドは部分一致用ワイルドカードを使えないので、2を直接表現できない)
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      # アカウントIDの直接指定と等価で、「指定のアカウント内のAssumeRoleが可能なプリンシパルすべて」という意味
      # 実質的に「"このRoleに誰がAssumeできるか"の取り決めを指定アカウント側に委ねる」という意味になる
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.trusted_account_id}:root"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${var.trusted_account_id}:role/aws-reserved/sso.amazonaws.com/*"]
    }
  }
}

# Prodアカウント上でTerraformを実行するためのロール（上記のtrust policyをattach）
resource "aws_iam_role" "terraform_exec" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

# 作成するロールにattachするpermission policy
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.terraform_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
