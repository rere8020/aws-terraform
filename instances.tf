#get Linux AMI ID using SSM Parameter endpoint in us-east-1
data "aws_ssm_parameter" "linuxAmi" {
  provider = aws.region-main
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#get Linux AMI ID using SSM Parameter endpoint in us-west-2
data "aws_ssm_parameter" "linuxAmiWest" {
  provider = aws.region-secondary
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#create key-pair for logging into EC2 in us-east-1
resource "aws_key_pair" "main-key" {
  provider   = aws.region-main
  key_name   = "terraform"
  public_key = file("~/.ssh/terraform.pub")
}

#create key-pair for logging into EC2 in us-west-2
resource "aws_key_pair" "secondary-key" {
  provider   = aws.region-secondary
  key_name   = "terraform"
  public_key = file("~/.ssh/terraform.pub")
}

#create and bootstrap EC2 in us-east-1
resource "aws_instance" "jenkins-main" {
  provider                    = aws.region-main
  ami                         = data.aws_ssm_parameter.linuxAmi.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.main-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  subnet_id                   = aws_subnet.subnet_1_east.id

  tags = {
    Name = "jenkins_main_tf"
  }

  depends_on = [aws_main_route_table_association.set-main-default-rt-assoc]

  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-main} --instance-ids ${self.id}
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/jenkins-main-sample.yml
EOF
  }
}

#create EC2 in us-west-2
resource "aws_instance" "jenkins-secondary-west" {
  provider                    = aws.region-secondary
  count                       = var.secondary-count
  ami                         = data.aws_ssm_parameter.linuxAmiWest.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.secondary-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg-west.id]
  subnet_id                   = aws_subnet.subnet_1_west.id

  tags = {
    Name = join("_", ["jenkins_secondary_tf", count.index + 1])
  }
  depends_on = [aws_main_route_table_association.set-secondary-rt-assoc, aws_instance.jenkins-main]

  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-secondary} --instance-ids ${self.id}
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/jenkins-secondary-sample.yml
EOF
  }
}

/*
###This template can also be put inside outputs.tf for better segregation 
output "Jenkins-Main-Node-Public-IP" {
  value = aws_instance.jenkins-main.public_ip
}

output "Jenkins-Secondary-Public-IPs" {
  value = {
    for instance in aws_instance.jenkins-secondary-west :
    instance.id => instance.public_ip
  }
}
*/