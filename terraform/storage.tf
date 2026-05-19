# Create the S3 Vector Bucket
resource "aws_s3vectors_vector_bucket" "s3-vector-test-vector-store" {
  vector_bucket_name = "s3-vector-test-vector-store"

  # Can add encryption config here
  encryption_configuration {
    sse_type = "AES256"
  }

  tags = {
    Name = "s3-vector-test-vector-store"
    Type = "Private"
  }
}

# Create a Vector Index
resource "aws_s3vectors_index" "main_index" {
  index_name         = "cat-index"
  vector_bucket_name = aws_s3vectors_vector_bucket.s3-vector-test-vector-store.vector_bucket_name

  data_type       = "float32"
  dimension       = 256
  distance_metric = "cosine"
}

# Bucket for storing application zip artifacts
resource "aws_s3_bucket" "s3-vector-test-lambda-deployments-bucket" {
  bucket = "s3-vector-test-lambda-deployments-bucket"

}

resource "aws_s3_bucket_public_access_block" "s3-vector-test-lambda-deployments-bucket-pab" {
  bucket = aws_s3_bucket.s3-vector-test-lambda-deployments-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "search_code_artifact" {
  bucket = aws_s3_bucket.s3-vector-test-lambda-deployments-bucket.id
  key    = "v1.0.0/search_index.zip" # Using a folder path mimics version control
  source = data.archive_file.search_lambda_zip.output_path

  # Tracks file changes so Terraform knows when to re-upload code
  source_hash = data.archive_file.search_lambda_zip.output_md5
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3-vector-test-lambda-deployments-bucket-encryption" {
  bucket = aws_s3_bucket.s3-vector-test-lambda-deployments-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_policy" "s3-vector-test-image-uploads-policy" {
  bucket = aws_s3_bucket.s3-vector-test-image-uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_exec.arn
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = ["${aws_s3_bucket.s3-vector-test-image-uploads.arn}/*"]
      }
    ]
  })
}
# Bucket for storing images to be indexed
resource "aws_s3_bucket" "s3-vector-test-image-uploads" {
  bucket = "s3-vector-test-image-uploads"
}

resource "aws_s3_bucket_public_access_block" "s3-vector-test-image-uploads-pab" {
  bucket = aws_s3_bucket.s3-vector-test-image-uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3-vector-test-image-uploads-encryption" {
  bucket = aws_s3_bucket.s3-vector-test-image-uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}