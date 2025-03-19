# Fetch the AWS account ID dynamically
data "aws_caller_identity" "current" {}

# Reference the existing IAM role
data "aws_iam_role" "alb-controller-role" {
  name = "CustomerManaged-eks-alb-ingress-controller" # Replace with your actual role name
}