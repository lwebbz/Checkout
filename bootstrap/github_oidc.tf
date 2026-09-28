# One GitHub Actions OIDC provider per account. The CI roles that trust it
# (and the repo/branch/environment conditions) live in the iam layer.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

}
