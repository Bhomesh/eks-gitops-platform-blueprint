variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "bank-prod-eks"
}

variable "cluster_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "system_node_min_size" {
  description = "Minimum size for system On-Demand node group"
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Maximum size for system On-Demand node group"
  type        = number
  default     = 6
}

variable "system_node_desired_size" {
  description = "Desired size for system On-Demand node group"
  type        = number
  default     = 2
}

variable "workload_node_min_size" {
  description = "Minimum size for workload Spot node group"
  type        = number
  default     = 2
}

variable "workload_node_max_size" {
  description = "Maximum size for workload Spot node group"
  type        = number
  default     = 10
}

variable "workload_node_desired_size" {
  description = "Desired size for workload Spot node group"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "Terraform"
    Compliance  = "SOC2-PCI"
  }
}
