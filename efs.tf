# EFS
resource "aws_efs_file_system" "model_cache" {
  creation_token = "kubeai-model-cache"
  tags = {
    Name = "Kubeai-ModelCache"
  }
}

# EFS Mount Target
resource "aws_efs_mount_target" "model_cache_mount" {
  file_system_id  = aws_efs_file_system.model_cache.id
  subnet_id       = data.aws_subnets.public_subnets.ids[0]
  security_groups = [data.aws_security_groups.public_security_group.ids[0]]
}

# EFS CSI Driver Helm Release
resource "helm_release" "aws_efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "2.4.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
}

# EFS Storage Class
resource "kubernetes_storage_class" "efs_sc" {
  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.model_cache.id
    directoryPerms   = "700"
  }
  depends_on = [helm_release.aws_efs_csi_driver]
}

# EFS Persistent Volume
resource "kubernetes_persistent_volume" "efs_pv" {
  metadata {
    name = "kubeai-efs-pv"
  }
  spec {
    capacity = {
      storage = "100Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.model_cache.id
      }
    }
    storage_class_name = "efs-sc"
  }
  depends_on = [kubernetes_storage_class.efs_sc]
}

# EFS Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "efs_pvc" {
  metadata {
    name      = "kubeai-efs-pvc"
    namespace = "kubeai"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    storage_class_name = "efs-sc"
  }
  depends_on = [kubernetes_persistent_volume.efs_pv, kubernetes_namespace.kubeai]
}
