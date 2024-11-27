# Provider configuration
provider "aws" {
  region = "ap-south-1"
}

# VPC Module
module "vpc" {
  source     = "./vpc"
  cidr_block = "10.0.0.0/16"
}

# Subnet Module
module "subnet" {
  source                         = "./subnet"
  vpc_id                         = module.vpc.vpc_id
  public_subnet_cidr             = "10.0.1.0/24"
  private_subnet_cidr            = "10.0.2.0/24"
  public_subnet_availability_zone = "ap-south-1a"
  private_subnet_availability_zone = "ap-south-1b"
}

# Internet Gateway Module
module "internet_gateway" {
  source  = "./igw"
  vpc_id  = module.vpc.vpc_id
}

# NAT Gateway Module
module "nat_gateway" {
  source           = "./nat"
  public_subnet_id = module.subnet.public_subnet_id
}

# Route Table Module
module "route_table" {
  source              = "./route_table"
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.internet_gateway.internet_gateway_id
  nat_gateway_id      = module.nat_gateway.nat_gateway_id
  public_subnet_id    = module.subnet.public_subnet_id
  private_subnet_id   = module.subnet.private_subnet_id
}

resource "aws_security_group" "allow_ssh" {
 name  ="allow-ssh-http"
 
 ingress {
   from_port = 22
   to_port   = 22
   protocol  = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
   from_port = 80
   to_port   = 80
   protocol  = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }

 egress {
   from_port = 0
   to_port   = 0
   protocol  = -1
   cidr_blocks = ["0.0.0.0/0"]
 }
}



# EC2 Instance Module
module "ec2_instance" {
  source           = "./ec2"
  ami_id           = "ami-0dee22c13ea7a9a67" # Example AMI for Amazon Linux 2, update as needed
  instance_type    = "t2.micro"
  private_subnet_id = module.subnet.private_subnet_id
  security_groups = [aws_security_group.allow_ssh.name]
}




# Load Balancer Module
module "load_balancer" {
  source          = "./load_balancer"
  vpc_id          = module.vpc.vpc_id
  subnets         = [module.subnet.public_subnet_id, module.subnet.private_subnet_id]
  security_groups = [] # Provide security group IDs if necessary
  ec2_instance_id = module.ec2_instance.instance_id
}


resource "aws_iam_user" "iam" {
 count =length(var.iamuser)
 name  = var.iamusers[count.index]

}
resource "aws_iam_access_key" "key" {
 user = aws_iam_user.iam.name

output "secret_key" {
 value = aws_iam_access_key.key.secret
 sensitive = true
}
output "access_key" {
 value = aws_iam_access_key.key.id

}
resource "aws_iam_policy" "policy" {
  name        = "test_policy"
  user        = aws_iam_user.iam.name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
