terraform {
  backend "s3" {
    bucket = "terraform-state-karen"
    key    = "assignment/alb-asg/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}