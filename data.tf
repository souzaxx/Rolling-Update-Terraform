data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "selected" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["rolling_update*"]
  }
}
