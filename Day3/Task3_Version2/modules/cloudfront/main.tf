data "aws_iam_policy_document" "s3" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cdn_oac_policy" {
  bucket = var.s3_bucket_id
  policy = data.aws_iam_policy_document.s3.json
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3_oac_policy"
  description                       = "s3_oac_policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = var.s3_log_bucket_id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_cloudfront_distribution" "cf" {
  depends_on = [aws_s3_bucket_ownership_controls.this]

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
    origin_id                = "s3-origin"
    origin_path              = var.origin_path
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "apdev-cdn"
  default_root_object = var.default_root_object
  
  default_cache_behavior {
    cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    target_origin_id = "s3-origin"
    

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.this[0].arn
    }
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
    
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  dynamic "logging_config" {
    for_each = var.enable_access_logs ? [var.logging_config] : []

    content {
      bucket          = format("%s.s3.amazonaws.com", var.logging_config.s3_bucket_name)
      include_cookies = logging_config.value.include_cookies
      prefix          = logging_config.value.prefix
    }
  }

  web_acl_id = var.enable_waf ? var.waf_id : null
  
  tags = var.tags
}

resource "aws_cloudfront_function" "this" {
  count   = var.enable_cloudfront_function ? 1 : 0

  name    = var.cloudfront_function_name
  runtime = var.cloudfront_function_runtime
  publish = var.cloudfront_function_publish
  code    = file("${path.module}/../../src${var.cloudfront_function_code_path}")
}