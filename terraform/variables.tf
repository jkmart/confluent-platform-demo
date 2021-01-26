variable "vpc_id" {
  description = "Specify the AWS VPC ID to use."
}

variable "sg_id" {
  description = "Specify the VPC Security Group within which to create demo instances. This Security Group can be used to open ports to the underlying EC2 instances, to include Brokers (9092), C3 (9021), and Connect (8083)."
}

variable "key_name" {
  description = "The name of the private key to use when creating EC2 instances."
}

variable "private_key_path" {
  description = "Path to the local private key for the specified EC2 instance key."
}