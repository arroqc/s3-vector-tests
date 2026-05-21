resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_vector_access" {
  name = "lambda_s3_vector_access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3vectors:QueryVectors",
          "s3vectors:InsertVectors",
          "s3vectors:GetVector"
        ]
        Resource = [aws_s3vectors_index.main_index.index_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.s3-vector-test-image-uploads.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = ["arn:aws:bedrock:*::foundation-model/amazon.nova-2-multimodal-embeddings-v1"]
      }
    ]
  })
}

resource "aws_lambda_function" "search_lambda" {
  function_name    = "vector-search-service"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.search_lambda_zip.output_path
  source_code_hash = data.archive_file.search_lambda_zip.output_md5
  timeout          = 30

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      INDEX_PATH = aws_s3vectors_index.main_index.index_arn
    }
  }
  layers = [aws_lambda_layer_version.lambda_deps.arn]
}

resource "aws_lambda_layer_version" "lambda_deps" {
  filename            = "${path.module}/../lambda_layer/lambda_layer.zip"
  layer_name          = "lambda_deps"
  compatible_runtimes = ["python3.11"]
}
