# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


provider "azurerm" {
  features {}
  // You can also specify subscription_id, client_id, client_secret, tenant_id
  // if not using Azure CLI login or other environment-based auth.
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  cluster_name        = "hybrid-aks-${random_string.suffix.result}"
  resource_group_name = "${var.resource_group_name_prefix}-${random_string.suffix.result}"
  vnet_name           = "hybrid-vnet"
  aks_subnet_name     = "aks-subnet"
  nat_pip_name        = "${local.cluster_name}-nat-pip"
  nat_gateway_name    = "${local.cluster_name}-natgw"
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet for AKS nodes
resource "azurerm_subnet" "aks_subnet" {
  name                 = local.aks_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat_pip" {
  name                = local.nat_pip_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway
resource "azurerm_nat_gateway" "aks_nat_gateway" {
  name                    = local.nat_gateway_name
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "aks_nat_gateway_association" {
  nat_gateway_id       = azurerm_nat_gateway.aks_nat_gateway.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

# Associate NAT Gateway with AKS Subnet
resource "azurerm_subnet_nat_gateway_association" "aks_subnet_nat_association" {
  subnet_id      = azurerm_subnet.aks_subnet.id
  nat_gateway_id = azurerm_nat_gateway.aks_nat_gateway.id
}


# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${local.cluster_name}-dns"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                 = "systempool"
    vm_size              = "Standard_DS2_v2"
    node_count           = var.system_pool_node_count
    vnet_subnet_id       = azurerm_subnet.aks_subnet.id
    os_disk_size_gb      = 30
    type                 = "VirtualMachineScaleSets"
    zones                = ["1", "2"]
    tags = {
      "nodepool-type" = "system"
      "environment"   = "hybrid-test"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = "10.1.0.0/16"
    dns_service_ip     = "10.1.0.10"
  }

  tags = {
    "environment" = "hybrid-test"
    "project"     = "hybrid-project"
  }
  depends_on = [
    azurerm_subnet_nat_gateway_association.aks_subnet_nat_association
  ]
}

# User Node Pool "apigee-runtime"
resource "azurerm_kubernetes_cluster_node_pool" "apigee_runtime" {
  name                  = "apigeerun"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v3"
  min_count             = var.runtime_pool_enable_autoscaling ? var.runtime_pool_min_count : null
  max_count             = var.runtime_pool_enable_autoscaling ? var.runtime_pool_max_count : null
  enable_auto_scaling   = var.runtime_pool_enable_autoscaling
  node_count            = var.runtime_pool_enable_autoscaling ? null : var.runtime_pool_node_count # Set node_count to null if autoscaling is enabled
 
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  os_disk_size_gb       = 128
  os_type               = "Linux"
  mode                  = "User"
  zones                 = ["1", "2"]

  tags = {
    "nodepool-purpose" = "apigee-runtime"
    "environment"      = "hybrid-test"
  }
}

# User Node Pool "apigee-data"
resource "azurerm_kubernetes_cluster_node_pool" "apigee_data" {
  name                  = "apigeedata"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v3"
  min_count             = var.data_pool_enable_autoscaling ? var.data_pool_min_count : null
  max_count             = var.data_pool_enable_autoscaling ? var.data_pool_max_count : null
  enable_auto_scaling   = var.data_pool_enable_autoscaling
  node_count            = var.data_pool_enable_autoscaling ? null : var.data_pool_node_count

  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  os_disk_size_gb       = 128
  os_type               = "Linux"
  mode                  = "User"
  zones                 = ["1"]

  tags = {
    "nodepool-purpose" = "apigee-data"
    "environment"      = "hybrid-test"
  }
}

resource "null_resource" "cluster_setup" {
  # Use local-exec provisioner to run a script to configure kubectl
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${local.resource_group_name} --name ${local.cluster_name} --overwrite-existing"
  }
  depends_on = [
    azurerm_kubernetes_cluster_node_pool.apigee_runtime,
    azurerm_kubernetes_cluster_node_pool.apigee_data,
    azurerm_kubernetes_cluster.aks,
  ]
}


output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

