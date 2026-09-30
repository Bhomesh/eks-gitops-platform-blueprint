# KMS Customer Managed Key for EKS Secrets Envelope Encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS Key for EKS Secrets Envelope Encryption (${var.cluster_name})"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-secrets-kms-key"
    }
  )
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
