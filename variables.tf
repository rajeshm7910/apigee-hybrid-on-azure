variable "resource_group_name_prefix" {
  description = "Prefix for the resource group name. A random suffix will be appended."
  type        = string
  default     = "hybrid-aks-rg"
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "East US" # Choose a default region
}

# System Node Pool Variables
variable "system_pool_node_count" {
  description = "The number of nodes for the system node pool."
  type        = number
  default     = 1
}

# Apigee Runtime Node Pool Variables
variable "runtime_pool_min_count" {
  description = "Minimum number of nodes for the Apigee Runtime node pool."
  type        = number
  default     = 2
}

variable "runtime_pool_max_count" {
  description = "Maximum number of nodes for the Apigee Runtime node pool."
  type        = number
  default     = 2
}

variable "runtime_pool_enable_autoscaling" {
  description = "Whether to enable autoscaling for the Apigee Runtime node pool."
  type        = bool
  default     = true
}

# Apigee Data Node Pool Variables
variable "data_pool_min_count" {
  description = "Minimum number of nodes for the Apigee Data node pool."
  type        = number
  default     = 1
}

variable "data_pool_max_count" {
  description = "Maximum number of nodes for the Apigee Data node pool."
  type        = number
  default     = 1
}

variable "data_pool_enable_autoscaling" {
  description = "Whether to enable autoscaling for the Apigee Data node pool."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Check for latest supported version in your region."
  type        = string
  default     = "1.31" # Adjusted to a more generally available recent version, update as needed
}