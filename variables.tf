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

variable "runtime_pool_node_count" {
  description = "Node count in case autoscaling is false."
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

variable "data_pool_node_count" {
  description = "Number of nodes for the Apigee Data node pool in case autoscale is false"
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

#######################################
#### GCP/Apigee Specific variables ####
#######################################

variable "project_id" {
  description = "The GCP project ID where Apigee Hybrid will be set up."
  type        = string
  # Example: "apigee-gke-example3"
}

variable "region" {
  description = "The GCP region for Apigee resources like analytics and runtime instance location."
  type        = string
  default     = "us-central1" # Choose a region appropriate for your K8s cluster
}

variable "apigee_org_display_name" {
  description = "Display name for the Apigee Organization."
  type        = string
  default     = "Apigee GKE Example3"
}

variable "apigee_env_name" {
  description = "Name for the Apigee Environment (e.g., dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "apigee_env_display_name" {
  description = "Display name for the Apigee Environment."
  type        = string
  default     = "Development Environment"
}

variable "apigee_instance_name" {
  description = "Name for the Apigee Runtime Instance (representing your K8s cluster)."
  type        = string
  default     = "hybrid-instance-1" # e.g., us-central1-hybrid-cluster
}

variable "apigee_envgroup_name" {
  description = "Name for the Apigee Environment Group."
  type        = string
  default     = "api-proxy-group"
}

variable "apigee_envgroup_hostnames" {
  description = "List of hostnames for the Environment Group."
  type        = list(string)
  default     = ["api.example.com"] # Replace with your actual domain(s)
}


variable "apigee_cassandra_replica_count" {
  description = "Cassandra Replica Count."
  type        = number
  default     = 1
}

variable "apigee_install" {
  description = "Indicates whether to install Apigee components. Set to true to install Apigee, false otherwise."
  type        = bool
  default     = true
}

variable "create_org" {
  description = "Indicates whether to install Apigee components. Set to true to install Apigee, false otherwise."
  type        = bool
  default     = false
}
variable "billing_type" {
  description = "Billing type for the Apigee organization (EVALUATION or PAID)."
  type        = string
  default     = "EVALUATION"
}

variable "overrides_template_path" {
  description = "Path to the overrides template file (e.g., overrides-templates.txt)."
  type        = string
  default     = "overrides-templates.yaml" # Or make it a required input
}

variable "service_template_path" {
  description = "Path to the overrides template file (e.g., overrides-templates.txt)."
  type        = string
  default     = "apigee-service-template.yaml" # Or make it a required input
}


variable "apigee_namespace" {
  description = "The Kubernetes namespace where Apigee components will be deployed."
  type        = string
  default     = "apigee"
}

variable "ingress_name" {
  description = "Name for the ingress gateway (max 17 characters)."
  type        = string
  default     = "apigee-ingress"
}

variable "ingress_svc_annotations" {
  description = "A map of annotations to apply to the ingress gateway service. Example: { \"service.beta.kubernetes.io/azure-load-balancer-internal\": \"true\" }"
  type        = map(string)
  default     = {} # Empty map by default, provide your annotations here
}

variable "apigee_version" {
  description = "Name for the ingress gateway (max 17 characters)."
  type        = string
  default     = "1.14.2-hotfix.1"
}

