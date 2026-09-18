# Active Storage 用バケット
resource "aws_s3_bucket" "active_storage" {
  bucket        = "${var.name_prefix}-active-storage-${var.account_id}"
  force_destroy = !var.is_prod
}

resource "aws_s3_bucket_public_access_block" "active_storage" {
  bucket                  = aws_s3_bucket.active_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "active_storage" {
  bucket = aws_s3_bucket.active_storage.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "active_storage" {
  bucket = aws_s3_bucket.active_storage.id
  versioning_configuration {
    status = var.is_prod ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "active_storage" {
  bucket = aws_s3_bucket.active_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "active_storage" {
  bucket = aws_s3_bucket.active_storage.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-old-versions"
    status = var.is_prod ? "Enabled" : "Disabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "active_storage" {
  count  = length(var.allowed_origins) > 0 ? 1 : 0
  bucket = aws_s3_bucket.active_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = var.allowed_origins
    expose_headers  = ["Origin", "Content-Type", "Content-MD5", "Content-Disposition"]
    max_age_seconds = 3600
  }
}

# TLS 以外を拒否
data "aws_iam_policy_document" "active_storage" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.active_storage.arn,
      "${aws_s3_bucket.active_storage.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "active_storage" {
  bucket = aws_s3_bucket.active_storage.id
  policy = data.aws_iam_policy_document.active_storage.json

  depends_on = [aws_s3_bucket_public_access_block.active_storage]
}
