
data "aws_ami" "ami" {

    owners = [ "amazon" ]
    most_recent = true
    
    filter {
      name = "name"
      values = ["amzn2-ami-kernel-*-gp2"]
    }
}