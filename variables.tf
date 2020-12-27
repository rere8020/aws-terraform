variable "profile" {
  type    = string
  default = "default"
}

variable "region-main" {
  type    = string
  default = "us-east-1"
}

variable "region-secondary" {
  type    = string
  default = "us-west-2"
}

variable "external_ip" {}

variable "secondary-count" {
  type    = number
  default = 1
}

variable "instance-type" {
  type    = string
  default = "t3.micro"
}