variable "vpc_cidr" {
  default = "10.20.0.0/16"
}

variable "public_subnet_a_cidr" {
  default = "10.20.10.0/24"
}

variable "public_subnet_b_cidr" {
  default = "10.20.20.0/24"
}

variable "az_a" {
  default = "us-east-1a"
}

variable "az_b" {
  default = "us-east-1b"
}