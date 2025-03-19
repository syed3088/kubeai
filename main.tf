terraform {
  backend "s3" {
    profile  = "saml"
    bucket   = "terraform-state-k"
    key      = "kubeai/applications/terraform.tfstate"
    region   = "us-east-1"
    encrypt  = true
  }
}

# Fetch existing EKS cluster
data "aws_eks_cluster" "kubeai" {
  name = var.cluster_name
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "tag:Name"
    values = ["dev-public-1", "dev-public-3"]
  }
}

data "aws_security_groups" "public_security_group" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "group-name"
    values = ["*Public*"]
  }
}

# Create namespace
resource "kubernetes_namespace" "kubeai" {
  metadata {
    name = "kubeai"
  }
}

# AWS Load Balancer Controller Helm Release
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = data.aws_iam_role.alb-controller-role.arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

# KubeAI Deployment
resource "helm_release" "kubeai" {
  name             = "kubeai"
  chart            = "../kubeai/charts/kubeai" # Local path to your cloned KubeAI repo
  namespace        = "kubeai"
  create_namespace = false
  values           = [file("values.yaml")]

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.storageClass"
    value = "efs-sc"
  }
  set {
    name  = "persistence.size"
    value = "100Gi"
  }
  set {
    name  = "secrets.huggingface.name"
    value = "huggingface-secret"
  }
  set {
    name  = "secrets.huggingface.create"
    value = "false"
  }

  depends_on = [
    helm_release.aws_lb_controller,
    kubernetes_persistent_volume_claim.efs_pvc,
    kubernetes_secret.huggingface_secret,
    kubernetes_secret.tls_certs
  ]
}
# ALB Ingress with TLS
resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name      = "app-ingress"
    namespace = "kubeai"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internal"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/subnets"         = join(",", data.aws_subnets.public_subnets.ids)
      "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
      "alb.ingress.kubernetes.io/healthcheck-port" = "8081"
      "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ "HTTPS" : 443 }, { "HTTP" : 80 }])
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:4761334568:certificate/84ee5a25-7e18-4c5d-92c1-44566466d"
      # Add your ACM ARN here if using HTTPS
      #"kubernetes.io/ingress.class" = "alb"
    }
  }
  spec {
    ingress_class_name = "alb"
    tls {
      secret_name = "tls-certs-kubeai"
      hosts       = ["flow.net"]
    }
    rule {
      host = "flow.net"
      http {
        path {
          path      = "/kubeai"
          path_type = "Prefix"
          backend {
            service {
              name = "kubeai"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/openwebui"
          path_type = "Prefix"
          backend {
            service {
              name = "openwebui"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.kubeai,
    #helm_release.openwebui,
    helm_release.aws_lb_controller,
    kubernetes_secret.tls_certs,
    kubernetes_namespace.kubeai
  ]
}
