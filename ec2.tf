# Creates midserver with basic configuration with the instance profile, IAM policy, role in developement account.

# IAM Role for midserver on Dev account 

resource "aws_iam_role" "IAM_role_for_EC2" {
 name   = "IAM_role_for_EC2"
 assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# SSM_managed_policy Attachment on the IAM_role_for_EC2.

resource "aws_iam_role_policy_attachment" "policy_attach" {
  role        = aws_iam_role.IAM_role_for_EC2.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# instance_profile for the MID server EC2 Instance

resource "aws_iam_instance_profile" "SSM_Instance_Profile" {
  name = "SSM_Instance_Profile"
  role = aws_iam_role.IAM_role_for_EC2.name
}

# security group for the MID server

resource "aws_security_group" "ssminstance_sg" {
  name        = "ssminstance_sg"
  description = "security group for SSM Server"
  vpc_id      = "vpc-cd1006b7"
  ingress {
    description      = "Open hhtps to Internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# EC2 instance for MID server

resource "aws_instance" "MIDserver" {
  ami           = "ami-0b0af3577fe5e3532" # us-east-1
  instance_type = "t2.micro"
  subnet_id = "subnet-416dac60"
  availability_zone = "us-east-1b"
  iam_instance_profile = aws_iam_instance_profile.SSM_Instance_Profile.name
  vpc_security_group_ids = [
    aws_security_group.ssminstance_sg.id
  ]
  user_data = <<EOF
#!/bin/bash

sudo yum update -y

echo "Install Python and ssm agent"
sudo yum install python2 -y
sudo dnf install -y https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm 

echo "Install aws cli"
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo yum install zip unzip -y
sudo unzip awscliv2.zip
sudo ./aws/install

echo "create new user miduser"
sudo adduser miduser
sudo passwd -d miduser
sudo usermod -aG wheel miduser
sudo su - miduser

echo "Copy MID binary from s3 to MID"
aws s3 cp s3://midserver/midserver_zipfile/mid-linux-installer.rome-06-23-2021__patch7-02-09-2022_02-23-2022_0935.linux.x86-64.rpm mid-linux-installer.rome-06-23-2021__patch7-02-09-2022_02-23-2022_0935.linux.x86-64.rpm
rpm -i mid-linux-installer.rome-06-23-2021__patch7-02-09-2022_02-23-2022_0935.linux.x86-64.rpm
EOF
}
