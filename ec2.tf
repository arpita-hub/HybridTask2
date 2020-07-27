provider "aws" {
  region                  = "us-east-1"
  profile                 = "arpita"
}
#generate a private key
resource "tls_private_key" "key1" {
  algorithm   = "RSA"
 
}

resource "aws_key_pair" "instkey" {
  key_name   = "hybrid1"
  public_key =  tls_private_key.key1.public_key_openssh 


}

#Store the generated key into local file keyos.pem
resource "local_file" "mykeyfile" {
    content     = tls_private_key.key1.private_key_pem 
    filename =  "hybrid1.pem"
}


variable "cidr_vpc"{
  description = "Newtork Range of VPC"
  default = "10.0.0.0/28"
}


#Variable For Subnet Range From VPC Range


variable "cidr_subnet1"{
  description = "Network Range From VPC"
  default = "10.0.0.0/28"
}


#Created a VPC(NAAS)


resource "aws_vpc" "myvpc"{
cidr_block = "${var.cidr_vpc}"
enable_dns_hostnames = true
 tags = {
   Name = "HybridCloud"
   }
}


#Created a Public-Subnet
 
resource "aws_subnet" "Public_Sub"{
  vpc_id = "${aws_vpc.myvpc.id}"
  cidr_block = "${var.cidr_subnet1}"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
  Name = "Public_Subnet"
  }
}

#Internet Gateway

resource "aws_internet_gateway" "IG"{
  vpc_id = "${aws_vpc.myvpc.id}"
  tags = {
   Name = "MyIG"
 }
}

resource "aws_route_table" "RouteTable"{
  vpc_id = "${aws_vpc.myvpc.id}"

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.IG.id}"
  }
 tags ={
 Name = "RouteTable"
}
}

resource "aws_route_table_association" "SUBNET_ASSO" {
  subnet_id      = "${aws_subnet.Public_Sub.id}"
  route_table_id = "${aws_route_table.RouteTable.id}"
}

#Assign Default Ip

resource "aws_default_subnet" "default_ip" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "AssignAutoIp"
  }
}

#Create Security Group

resource "aws_security_group" "sgtask2" {
  name        = "sgtask2"
  description = "Security Group for task2"
  vpc_id      = "${aws_vpc.myvpc.id}"


  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]


  }


    ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]


  }
    ingress {
    description = "allow nfs"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]


  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "sgtask2"
  }
}

#Variable for AMI_id(AMI_Image)


 variable "ami_id"{
 type = string
 default = "ami-08f3d892de259504d"
}


#Variable for AMI_Instance_Type


variable "ami_type"{
 type = string
 default = "t2.micro"
}


#Create a Instance


resource "aws_instance" "Task2Instance"{
 ami = "${var.ami_id}"
 instance_type = "${var.ami_type}"
 key_name = "hybrid1"
 subnet_id = "${aws_subnet.Public_Sub.id}"
 vpc_security_group_ids = ["${aws_security_group.sgtask2.id}"]


tags = {
 Name = "Task2"
}
}

#Create a Null_Resource and Remote Login into Our Instance


resource "null_resource" "null1"{
  depends_on = [
   aws_instance.Task2Instance
 ]
 connection {
     agent = "false"
     type = "ssh"
     user = "ec2-user"
     private_key = "${tls_private_key.key1.private_key_pem}"
     host = aws_instance.Task2Instance.public_ip
   }
provisioner "remote-exec"{  
   inline = [
        "sudo yum update -y",
	"sudo yum install httpd php git amazon-efs-utils nfs-utils -y",
        "sudo systemctl restart httpd",
        "sudo systemctl enable httpd",
      ]
 }
}

#Create EFS(Elastic File System)


resource "aws_efs_file_system" "EFS"{
 creation_token = "efs"
 tags = {
  Name = "EFS"
  }
}


#Mounting EFS


resource "aws_efs_mount_target" "efs_mount" {
 depends_on = [
    aws_efs_file_system.EFS
  ]
  file_system_id = "${aws_efs_file_system.EFS.id}"
  subnet_id      = "${aws_subnet.Public_Sub.id}"
  security_groups = ["${aws_security_group.sgtask2.id}"]
}

#Create a another null_resource to mount our EFS to Webserver
   
resource "null_resource" "null_remote"{
 depends_on = [
   null_resource.null1,
   aws_efs_mount_target.efs_mount,
 ]
connection{
  type = "ssh"
  user = "ec2-user"
  private_key  = "${tls_private_key.key1.private_key_pem}"
  host = "${aws_instance.Task2Instance.public_ip}"
}

provisioner "remote-exec"{
  inline = [
     "sudo mount -t efs ${aws_efs_file_system.EFS.id}:/ /var/www/html",
     "sudo rm -rf /var/www/html/",
     "sudo git clone https://github.com/arpita-hub/HybridTask2.git /var/www/html/",
    ]
 }
}

#Create a S3 Bucket

resource "aws_s3_bucket" "apps"{
 bucket ="hybrid-cloud-1"
 acl = "public-read"
  tags = {
    Name = "bucket1"
}
 versioning{
   enabled = true
}
}

#Create a S3 Bucket Object and Put in S3 Bucket

resource "aws_s3_bucket_object" "object1"{
	depends_on = [
		aws_s3_bucket.apps,
	]
  bucket = "${aws_s3_bucket.apps.bucket}"
  key = "IIEC_RISE.jpeg"
  source = "/home/apps/Desktop/IIEC_RISE.jpeg"
  acl = "public-read"
  content_type= "images or jpeg"
}	
