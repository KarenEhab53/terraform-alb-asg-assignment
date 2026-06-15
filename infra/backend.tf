terraform {
  backend "s3" {
    bucket         = "YOUR_BUCKET_NAME"
    key            = "assignment/alb-asg/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "YOUR_DYNAMODB_TABLE"
    encrypt        = true
  }
}