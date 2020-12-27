output "Jenkins-Main-Node-Public-IP" {
  value = aws_instance.jenkins-main.public_ip
}

output "Jenkins-Secondary-Public-IPs" {
  value = {
    for instance in aws_instance.jenkins-secondary-west :
    instance.id => instance.public_ip
  }
}