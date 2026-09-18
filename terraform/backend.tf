# リモート state。bucket / key / dynamodb_table は環境ごとに
#   terraform init -backend-config=environments/<env>.backend.hcl
# で渡す (partial configuration)。
terraform {
  backend "s3" {
    encrypt = true
  }
}
