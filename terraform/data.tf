data "aws_availability_zones" "available" {
  state = "available"
}

data "archive_file" "search_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../search_lambda"
  output_path = "${path.module}/../search_lambda/search_index.zip"
}