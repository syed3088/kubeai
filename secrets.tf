# Hugging Face Secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "huggingface_secret" {
  name                    = "huggingface"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "huggingface_secret_version" {
  secret_id     = aws_secretsmanager_secret.huggingface_secret.id
  secret_string = jsonencode({ token = var.huggingface_token })
}

# Kubernetes Secret for Hugging Face Token
resource "kubernetes_secret" "huggingface_secret" {
  metadata {
    name      = "huggingface-secret"
    namespace = "kubeai"
  }
  data = {
    token = var.huggingface_token
  }
  depends_on = [kubernetes_namespace.kubeai]
}

# Kubernetes Secret for TLS Certificates
resource "kubernetes_secret" "tls_certs" {
  metadata {
    name      = "tls-certs-kubeai"
    namespace = "kubeai"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = file("${path.module}/tls.crt")
    "tls.key" = file("${path.module}/tls.key")
  }
  depends_on = [kubernetes_namespace.kubeai]
}
