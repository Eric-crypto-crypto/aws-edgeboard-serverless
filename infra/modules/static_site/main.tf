data "aws_caller_identity" "current" {}

# ===== 1. 私有 S3 桶（中央仓库）=====
resource "aws_s3_bucket" "site" {
  bucket        = "${var.name}-site-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ===== 2. OAC（专属提货证）=====
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.name}-site-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always" # 每次请求都签名
  signing_protocol                  = "sigv4"
}

# 使用 AWS 托管的缓存策略（按名字查询，不用硬编码 ID）
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

# ===== 3. CloudFront 分发（全球便利店）=====
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  aliases             = [var.domain_name] # 告诉 CloudFront：这个分发也响应这个域名
  comment             = "${var.name} static site"
  default_root_object = "index.html"
  price_class         = "PriceClass_All" # 包含澳洲/新西兰节点
  http_version        = "http2and3"
  is_ipv6_enabled     = true

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name # 区域域名，不是网站托管地址
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # 第二个源站：API Gateway
  origin {
    origin_id   = "api"
    domain_name = var.api_domain

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only" # CloudFront 到 API 也必须用 HTTPS
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # /api/* 行为：不缓存，转发给 API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "api"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }


  default_cache_behavior {
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true # 自动 gzip / brotli 压缩
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 自定义域名的 ACM 证书
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

}

# ===== 4. 桶策略：只允许"这一个"分发读取 =====
data "aws_iam_policy_document" "site_bucket" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # 防止混淆代理：只允许我的分发，不允许别人的
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}

# ===== 5. ACM 证书（必须在 us-east-1）=====
resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  # 更换证书时，先创建新证书，再删除旧证书，避免网站出现没有证书的空档期
  lifecycle {
    create_before_destroy = true
  }
}

# 在 Route 53 中贴上"暗号纸条"（验证用的 CNAME 记录）
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# 等待 ACM 验证通过（这个资源本身不会创建任何东西，只负责"等待"）
resource "aws_acm_certificate_validation" "site" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ===== 6. DNS 记录：域名 → CloudFront（IPv4 + IPv6）=====
resource "aws_route53_record" "site" {
  for_each = toset(["A", "AAAA"])

  zone_id = var.zone_id
  name    = var.domain_name
  type    = each.key

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
