terraform { 
   required_providers { 
      aws = { 
         source = "hashicorp/aws" 
         version = "~> 4.0" 
      } 
   } 
} 
 
provider "aws" { 
   region = "us-east-1" 
   shared_credentials_files = ["./credentials"] 
}

locals { 
    image = "ghcr.io/csse6400/taskoverflow:latest" 
    database_username = "administrator" 
    database_password = "foobarbaz" # this is bad 
} 
 
resource "aws_db_instance" "taskoverflow_database" { 
 allocated_storage = 20 
 max_allocated_storage = 1000 
 engine = "postgres" 
 engine_version = "14" 
 instance_class = "db.t4g.micro" 
 db_name = "todo" 
 username = local.database_username 
 password = local.database_password 
 parameter_group_name = "default.postgres14" 
 skip_final_snapshot = true 
 vpc_security_group_ids = [aws_security_group.taskoverflow_database.id] 
 publicly_accessible = true 
 
 tags = { 
   Name = "taskoverflow_database" 
 } 
}

resource "aws_security_group" "taskoverflow_database" { 
 name = "taskoverflow_database" 
 description = "Allow inbound Postgresql traffic" 
 
 ingress { 
   from_port = 5432 
   to_port = 5432 
   protocol = "tcp" 
   cidr_blocks = ["0.0.0.0/0"] 
 } 
 
 egress { 
   from_port = 0 
   to_port = 0 
   protocol = "-1" 
   cidr_blocks = ["0.0.0.0/0"] 
   ipv6_cidr_blocks = ["::/0"] 
 } 
 
 tags = { 
   Name = "taskoverflow_database" 
 } 
}

resource "aws_instance" "taskoverflow_instance" { 
   ami = "ami-005f9685cb30f234b" # Amazon Linux 2 
   instance_type = "t2.micro" 
   key_name = "vockey" # allows SSH into the instance using the preconfigured key 
 
   user_data_replace_on_change = true # changing user_data will force recreate 
   user_data = <<-EOT
#!/bin/bash 
yum update -y 
yum install -y docker 
service docker start 
systemctl enable docker 
usermod -a -G docker ec2-user 
docker run --restart always -e SQLALCHEMY_DATABASE_URI=postgresql://${local.database_username}:${local.database_password}@${aws_db_instance.taskoverflow_database.address}:${aws_db_instance.taskoverflow_database.port}/${aws_db_instance.taskoverflow_database.db_name} -p 6400:6400 ${local.image} 
 EOT
 
   security_groups = [aws_security_group.taskoverflow_instance.name] # firewall for the instance 
 
   tags = { 
      Name = "taskoverflow_instance" 
   } 
}

resource "aws_security_group" "taskoverflow_instance" { 
   name = "taskoverflow_instance" 
   description = "TaskOverflow Security Group" 
 
   ingress { 
    from_port = 6400 
    to_port = 6400 
    protocol = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
   } 
 
   ingress { 
    from_port = 22 
    to_port = 22 
    protocol = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
   } 
 
   egress { 
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
   } 
}

output "url" { 
   value = "http://${aws_instance.taskoverflow_instance.public_ip}:6400/" 
}