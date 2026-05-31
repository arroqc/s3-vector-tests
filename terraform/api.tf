# HTTP API Gateway for vector search service
resource "aws_apigatewayv2_api" "search_api" {
  name          = "vector-search-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# Integration between API Gateway and Lambda
resource "aws_apigatewayv2_integration" "search_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.search_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.search_lambda.invoke_arn
  payload_format_version = "2.0"
}

# Route to the search Lambda
resource "aws_apigatewayv2_route" "search_route" {
  api_id    = aws_apigatewayv2_api.search_api.id
  route_key = "POST /search"
  target    = "integrations/${aws_apigatewayv2_integration.search_lambda_integration.id}"
}

# Route to presign endpoint for S3 uploads
resource "aws_apigatewayv2_route" "presign_route" {
  api_id    = aws_apigatewayv2_api.search_api.id
  route_key = "POST /presign"
  target    = "integrations/${aws_apigatewayv2_integration.search_lambda_integration.id}"
}

# Stage for the API
# NOTE: HTTP APIs have limited throttling. For production, use WAF or REST API Gateway.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.search_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda permission to allow API Gateway to invoke
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.search_api.execution_arn}/*/*"
}

# S3 bucket for website static files
resource "aws_s3_bucket" "website" {
  bucket = "s3-vector-test-website"
}

resource "aws_s3_bucket_public_access_block" "website_pab" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

# Render the HTML template with the API endpoint and S3 config
resource "local_file" "website_index" {
  filename = "${path.module}/../website/index.html.rendered"
  content = templatefile("${path.module}/../website/index.html", {
    api_gateway_url = aws_apigatewayv2_stage.default.invoke_url
    s3_bucket       = aws_s3_bucket.s3-vector-test-image-uploads.id
    s3_region       = var.aws_region
  })
}

# Upload rendered HTML to S3
resource "aws_s3_object" "website_index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = local_file.website_index.filename
  content_type = "text/html"
  etag         = local_file.website_index.id

  depends_on = [aws_s3_bucket_website_configuration.website]
}

# Outputs for website configuration
output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL for the search service"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "s3_bucket" {
  description = "S3 bucket for image uploads"
  value       = aws_s3_bucket.s3-vector-test-image-uploads.id
}

output "s3_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "website_url" {
  description = "Website S3 endpoint (HTTP - use CloudFront for HTTPS in production)"
  value       = "http://${aws_s3_bucket.website.bucket_regional_domain_name}"
}
