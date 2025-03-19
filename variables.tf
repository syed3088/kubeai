variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  default     = "vpc-0b5bet555"
}

variable "subnet_ids" {
  description = "Existing Subnet IDs"
  default     = ["subnet-0456464554", "subnet-05555568d0c"]
}

variable "cluster_name" {
  description = "Cluster name"
  default     = "kubeai-eks"
}