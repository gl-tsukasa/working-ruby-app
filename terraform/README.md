# AWS インフラ (Terraform)

このディレクトリは Rails アプリを AWS にデプロイするための Terraform 構成です。

## 構成

```
Internet
   │
   ▼
 ALB (public subnet, 2-3 AZ)  ── access log → S3
   │  HTTP→HTTPS redirect / ACM
   ▼
 ECS Fargate (private subnet)          Secrets Manager
   web service  ×N  (autoscaling)  ◀── DATABASE_URL / RAILS_MASTER_KEY
   migrate task (db:prepare)
   │                 │
   ▼                 ▼
 RDS PostgreSQL     S3 (Active Storage)
 (database subnet,  IAM task role で認証
  KMS 暗号化)
```

| モジュール | 内容 |
|---|---|
| `network` | VPC、public / private / database の 3 層サブネット、NAT (単一 or AZ 別)、S3 Gateway Endpoint、ECR / Logs / Secrets Manager / SSM の Interface Endpoint、VPC Flow Logs |
| `security` | ALB → ECS → RDS の順にだけ通すセキュリティグループ |
| `ecr` | イミュータブルタグ、push 時スキャン、ライフサイクルポリシー |
| `storage` | Active Storage 用 S3 (公開ブロック、暗号化、TLS 強制、CORS) |
| `database` | RDS PostgreSQL 16 (gp3、KMS、Performance Insights、拡張モニタリング、`rds.force_ssl`)、接続情報を Secrets Manager に保存 |
| `alb` | ALB、ターゲットグループ、HTTP / HTTPS リスナー、Route53 A レコード、アクセスログ |
| `ecs` | クラスタ、web / migrate タスク定義 (ARM64)、サービス (circuit breaker + rollback、ECS Exec)、CPU / リクエスト数のターゲット追跡スケーリング、非 prod の夜間スケールイン |
| `monitoring` | SNS、ALB 5xx 率 / p95 / Unhealthy、ECS CPU / メモリ、RDS CPU / ストレージ / 接続数のアラーム、ダッシュボード |

## 前提

- Terraform >= 1.5
- state 用 S3 バケットと DynamoDB ロックテーブル (`environments/<env>.backend.hcl` の `CHANGE-ME` を書き換える)
- AWS 認証 (ローカルは profile、CI は OIDC を想定)

## 初回デプロイ

```bash
cd terraform
terraform init -backend-config=environments/dev.backend.hcl
terraform plan  -var-file=environments/dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan
```

1. **RAILS_MASTER_KEY を投入する**
   ```bash
   aws secretsmanager put-secret-value \
     --secret-id "$(terraform output -raw rails_master_key_secret_arn)" \
     --secret-string "$(cat ../config/master.key)"
   ```
   もしくは `-var rails_master_key=...` で Terraform に渡す。

2. **イメージを push する**
   ```bash
   REPO=$(terraform output -raw ecr_repository_url)
   aws ecr get-login-password | docker login --username AWS --password-stdin "${REPO%%/*}"
   docker buildx build --platform linux/arm64 -t "$REPO:$(git rev-parse --short HEAD)" --push ..
   ```

3. **マイグレーションを流す**
   ```bash
   aws ecs run-task \
     --cluster "$(terraform output -raw ecs_cluster_name)" \
     --task-definition "$(terraform output -raw migrate_task_definition_arn)" \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=$(terraform output -json private_subnet_ids | tr -d ' \n'),securityGroups=[$(terraform output -raw app_security_group_id)],assignPublicIp=DISABLED}"
   ```

4. **タグを指定して apply する** (以降のデプロイはこれだけ)
   ```bash
   terraform apply -var-file=environments/dev.tfvars -var image_tag=$(git rev-parse --short HEAD)
   ```

## 環境差分

| | dev | prod |
|---|---|---|
| AZ / NAT | 2 AZ / NAT 1 台 | 3 AZ / NAT 3 台 |
| Fargate | 0.5 vCPU、Spot 混在、1〜3 台、夜間 1 台 | 1 vCPU、On-Demand、3〜12 台 |
| RDS | t4g.micro、単一 AZ、バックアップ 1 日 | r6g.large、Multi-AZ、14 日、削除保護 |
| 破壊的操作 | `force_destroy` / `skip_final_snapshot` 有効 | 削除保護、最終スナップショット取得 |

## 運用メモ

- `rails console` は ECS Exec で入る:
  `aws ecs execute-command --cluster <cluster> --task <task-id> --container web --interactive --command "bin/rails console"`
- DB のパスワードは Terraform の `random_password` で生成し Secrets Manager に置く。ローテーションする場合は `terraform taint module.database.random_password.master` で再生成する (接続断が起きるので prod はメンテ時間に)。
- `desired_count` はオートスケールが動かすため `ignore_changes` にしている。手で戻したいときはコンソールか CLI で。
- 外部 SaaS に送信元 IP を登録する場合は `nat_gateway_public_ips` の出力を使う。
