# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# No explicit provider "tls" {} block is needed unless you have specific proxy configurations for it.

locals {
  // Google Cloud / Apigee specific locals
  apigee_org_constructed_id = "organizations/${var.project_id}"
  service_account_id_short  = "apigee-non-prod"
  service_account_email     = "${local.service_account_id_short}@${var.project_id}.iam.gserviceaccount.com"

  effective_org_id = var.create_org ? (
    google_apigee_organization.apigee_org[0].id
  ) : local.apigee_org_constructed_id

  effective_env_name           = var.apigee_env_name
  effective_instance_name      = var.apigee_instance_name
  effective_envgroup_hostnames = var.apigee_envgroup_hostnames
  effective_envgroup_name      = var.apigee_envgroup_name

  effective_envgroup_id = var.create_org ? (
    google_apigee_envgroup.hybrid_envgroup[0].id
  ) : (local.effective_org_id != null ? "${local.effective_org_id}/envgroups/${var.apigee_envgroup_name}" : null)

  apigee_non_prod_sa_roles = [
    "roles/storage.objectAdmin",
    "roles/logging.logWriter",
    "roles/apigeeconnect.Agent",
    "roles/monitoring.metricWriter",
    "roles/apigee.synchronizerManager",
    "roles/apigee.analyticsAgent",
    "roles/apigee.runtimeAgent",
  ]

  primary_hostname_for_cert = length(var.apigee_envgroup_hostnames) > 0 ? var.apigee_envgroup_hostnames[0] : "default-apigee-host.example.com"
  cert_filename_prefix      = replace(local.primary_hostname_for_cert, ".", "-")

  # Basenames for files, as Helm charts expect paths relative to the chart.
  # The actual files are in output/{var.project_id}/
  # When applying the Helm chart, these files need to be copied to the chart's expected location,
  # or the chart needs to be configured to find them in output/{var.project_id}/ if possible.
  # For now, we provide the basenames as the template expects.
  sa_key_filename_for_overrides      = basename(local_file.apigee_non_prod_sa_key_file.filename)
  cert_file_path_for_overrides       = basename(local_file.apigee_envgroup_cert_file.filename)
  private_key_file_path_for_overrides = basename(local_file.apigee_envgroup_private_key_file.filename)

  # Generate YAML snippet for service annotations
  # This ensures proper YAML formatting for the map.
  # If no annotations, it will be an empty string.
  ingress_svc_annotations_yaml = length(var.ingress_svc_annotations) > 0 ? yamlencode({
    svcAnnotations = var.ingress_svc_annotations
  }) : ""

}

# ------------------------------------------------------------------------------
# Enable Google Cloud Services
# ... (existing service enablement resources remain the same) ...
resource "google_project_service" "iam" {
  project                    = var.project_id
  service                    = "iam.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "apigee" {
  project                    = var.project_id
  service                    = "apigee.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "compute" {
  project                    = var.project_id
  service                    = "compute.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "apigeeconnect" {
  project                    = var.project_id
  service                    = "apigeeconnect.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "storage" {
  project                    = var.project_id
  service                    = "storage.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "logging" {
  project                    = var.project_id
  service                    = "logging.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "monitoring" {
  project                    = var.project_id
  service                    = "monitoring.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Create Apigee Non-Prod Service Account
# ... (existing google_service_account.apigee_non_prod_sa remains the same) ...
resource "google_service_account" "apigee_non_prod_sa" {
  project      = var.project_id
  account_id   = local.service_account_id_short
  display_name = "Apigee Non-Prod Service Account"
  description  = "Service account for Apigee Hybrid non-production workloads (recreated on apply)"

  depends_on = [
    google_project_service.apigee,
    google_project_service.apigeeconnect,
    google_project_service.storage,
    google_project_service.logging,
    google_project_service.monitoring,
    google_project_service.iam,
  ]
}
# ------------------------------------------------------------------------------

# ... (existing google_project_iam_member.apigee_non_prod_sa_bindings remains the same) ...
resource "google_project_iam_member" "apigee_non_prod_sa_bindings" {
  for_each = toset(local.apigee_non_prod_sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.apigee_non_prod_sa.email}"
}

# ... (existing google_service_account_key.apigee_non_prod_sa_key remains the same) ...
resource "google_service_account_key" "apigee_non_prod_sa_key" {
  service_account_id = google_service_account.apigee_non_prod_sa.name
}

# Ensure the output directory exists (used for SA key and TLS certs)
resource "null_resource" "create_output_dir" { # Renamed for clarity, was create_sa_key_output_dir
  triggers = {
    # This ensures the provisioner runs if the project_id changes,
    # and acts as a dependency marker. Also, ensures it runs to create dir.
    output_dir_path = "output/${var.project_id}"
    always_run      = timestamp() # Ensures it runs to create directory if it doesn't exist
  }

  provisioner "local-exec" {
    command = "mkdir -p output/${var.project_id}"
  }
}

# Save the service account key to a local file
# ... (existing local_file.apigee_non_prod_sa_key_file, ensure depends_on uses new null_resource name) ...
resource "local_file" "apigee_non_prod_sa_key_file" {
  sensitive_content = base64decode(google_service_account_key.apigee_non_prod_sa_key.private_key)
  filename          = "output/${var.project_id}/${local.service_account_id_short}-sa-key.json"
  file_permission   = "0600"

  depends_on = [
    null_resource.create_output_dir, # Updated dependency
  ]
}

# ------------------------------------------------------------------------------
# Self-Signed TLS Certificate for Apigee Environment Group Hostnames
# ------------------------------------------------------------------------------
resource "tls_private_key" "apigee_envgroup_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "apigee_envgroup_cert" {
  private_key_pem = tls_private_key.apigee_envgroup_key.private_key_pem

  # Use all hostnames from the variable as DNS Subject Alternative Names (SANs)
  dns_names = var.apigee_envgroup_hostnames

  subject {
    # Use the first hostname as the Common Name (CN)
    common_name  = local.primary_hostname_for_cert
    organization = "Apigee Hybrid Self-Signed Cert"
  }

  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720  # 30 days

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth", # Optional, if you might use it for mTLS client-side
  ]

  # is_ca_certificate = false # Set to true if this cert will sign other certs
}

resource "local_file" "apigee_envgroup_private_key_file" {
  sensitive_content = tls_private_key.apigee_envgroup_key.private_key_pem
  filename          = "output/${var.project_id}/${local.cert_filename_prefix}.key"
  file_permission   = "0600" # Read/write for owner only

  depends_on = [
    null_resource.create_output_dir,
    tls_private_key.apigee_envgroup_key,
  ]
}

resource "local_file" "apigee_envgroup_cert_file" {
  content         = tls_self_signed_cert.apigee_envgroup_cert.cert_pem
  filename        = "output/${var.project_id}/${local.cert_filename_prefix}.crt"
  file_permission = "0644" # Read for all, write for owner

  depends_on = [
    null_resource.create_output_dir,
    tls_self_signed_cert.apigee_envgroup_cert,
  ]
}

# ------------------------------------------------------------------------------
# Define local variables for file paths and names for overrides.yaml template
# ------------------------------------------------------------------------------

# --- Generate Unique Instance ID for Apigee Hybrid ---
resource "random_id" "apigee_instance_id" {
  byte_length = 8
}
# --- Generate overrides.yaml file using templatefile ---
# This resource generates the overrides.yaml file based on a template.
# It uses the templatefile function to substitute variables into the template.
# The template file is specified by the var.template_filepath variable.
# The output file is named "overrides.yaml" and is placed in the output directory.

resource "local_file" "apigee_overrides" {
  content = templatefile(var.overrides_template_path, {
    instance_id                       = var.apigee_instance_name
    apigee_namespace                  = var.apigee_namespace
    project_id                        = var.project_id
    analytics_region                  = var.region
    cluster_name                      = local.cluster_name
    cluster_location                  = var.region
    org_name                          = var.project_id # Assuming project ID is used as org name
    environment_name                  = var.apigee_env_name
    cassandra_replica_count           = var.apigee_cassandra_replica_count
    non_prod_service_account_filepath = local.sa_key_filename_for_overrides
    ingress_name                      = var.ingress_name
    environment_group_name            = var.apigee_envgroup_name
    ssl_cert_path                     = local.cert_file_path_for_overrides
    ssl_key_path                      = local.private_key_file_path_for_overrides
    # Add any other variables from your template here
  })
  filename        = "output/${var.project_id}/overrides.yaml"
  file_permission = "0644"
}

resource "local_file" "apigee_service" {
  content = templatefile(var.service_template_path, {
    apigee_namespace                  = var.apigee_namespace
    org_name                          = var.project_id # Assuming project ID is used as org name
    ingress_name                      = var.ingress_name
    service_name                      = var.apigee_envgroup_name
    # Add any other variables from your template here
  })
  filename        = "output/${var.project_id}/apigee-service.yaml"
  file_permission = "0644"
}



# ------------------------------------------------------------------------------
# Apigee Organization, Environment, EnvGroup, Attachment
# ... (existing Apigee resources remain the same) ...
resource "google_apigee_organization" "apigee_org" {
  count = var.create_org ? 1 : 0
  project_id       = var.project_id
  display_name     = var.apigee_org_display_name
  description      = "Apigee Hybrid Organization managed by Terraform"
  analytics_region = var.region
  runtime_type     = "HYBRID"
  billing_type     = var.billing_type
  depends_on = [
    google_project_service.apigee,
    google_project_service.compute,
  ]
}
resource "google_apigee_environment" "hybrid_env" {
  count = var.create_org ? 1 : 0
  name         = local.effective_env_name
  display_name = var.apigee_env_display_name
  description  = "Hybrid Environment for ${local.effective_env_name}"
  org_id       = local.effective_org_id
  depends_on = [google_apigee_organization.apigee_org]
}
resource "google_apigee_envgroup" "hybrid_envgroup" {
  count = var.create_org ? 1 : 0
  name      = local.effective_envgroup_name
  hostnames = local.effective_envgroup_hostnames
  org_id    = local.effective_org_id
  depends_on = [google_apigee_organization.apigee_org]
}
resource "google_apigee_envgroup_attachment" "env_to_group_attachment" {
  count = var.create_org ? 1 : 0
  envgroup_id = local.effective_envgroup_id
  environment = local.effective_env_name
  depends_on = [google_apigee_environment.hybrid_env, google_apigee_envgroup.hybrid_envgroup]
}
# ------------------------------------------------------------------------------


resource "null_resource" "apigee_setup_execution" {
  # Only run if run_setup_script is true
  count = var.apigee_install ? 1 : 0
  # Triggers: Re-run this resource if any of these values change.
  triggers = {
    apigee_version                = var.apigee_version
    apigee_namespace              = var.apigee_namespace
    apigee_overrides_yaml_content = local_file.apigee_overrides.content # Trigger on content change of the overrides file
    apigee_service_yaml_content   = local_file.apigee_service.content # Trigger on content change of the service file
    apigee_sa_key_json_path       = abspath(local_file.apigee_non_prod_sa_key_file.filename)
    apigee_envgroup_cert_path     = abspath(local_file.apigee_envgroup_cert_file.filename)
    apigee_envgroup_key_path      = abspath(local_file.apigee_envgroup_private_key_file.filename)
    # Consider adding script content hash if you want to re-run when the script itself changes:
    script_hash                   = filemd5("./setup_apigee.sh")
  }

  provisioner "local-exec" {
    # Command to execute. Ensure setup_apigee.sh is in your PATH or provide a relative/absolute path
    # from the directory where you run `terraform apply`.
    # Using bash explicitly can be more robust.
    command = <<-EOT
      bash ./setup_apigee.sh \
        --version "${var.apigee_version}" \
        --namespace "${var.apigee_namespace}" \
        --overrides "${abspath(local_file.apigee_overrides.filename)}" \
        --service "${abspath(local_file.apigee_service.filename)}" \
        --key "${abspath(local_file.apigee_non_prod_sa_key_file.filename)}" \
        --cert "${abspath(local_file.apigee_envgroup_cert_file.filename)}" \
        --private-key "${abspath(local_file.apigee_envgroup_private_key_file.filename)}" 
    EOT
    # Optional: set working_directory if your script needs to run from a specific location
    # working_directory = path.module

    # Optional: environment variables for the script
    # environment = {
    #   MY_CUSTOM_VAR = "some_value"
    # }
  }

  # Ensure overrides.yaml is created before this script runs
  depends_on = [
    local_file.apigee_overrides,
    local_file.apigee_service,
    local_file.apigee_non_prod_sa_key_file,
    local_file.apigee_envgroup_cert_file,
    google_apigee_organization.apigee_org,
    google_apigee_environment.hybrid_env,
    google_apigee_envgroup.hybrid_envgroup,
    google_apigee_envgroup_attachment.env_to_group_attachment,
    null_resource.cluster_setup,
  ]
}

# --- Outputs ---
output "apigee_non_prod_sa_email" {
  description = "Email of the Apigee Non-Prod service account."
  value       = google_service_account.apigee_non_prod_sa.email
}

output "apigee_non_prod_sa_key_path" {
  description = "Path to the saved Apigee Non-Prod service account key file."
  value       = local_file.apigee_non_prod_sa_key_file.filename
}

output "apigee_overrides_yaml_path" {
  description = "Path to the generated Apigee Hybrid overrides.yaml file."
  value       = local_file.apigee_overrides.filename
}


output "apigee_envgroup_private_key_file_path" {
  description = "Path to the self-signed private key file for the Apigee envgroup hostname(s)."
  value       = local_file.apigee_envgroup_private_key_file.filename
}

output "apigee_envgroup_cert_file_path" {
  description = "Path to the self-signed certificate file for the Apigee envgroup hostname(s)."
  value       = local_file.apigee_envgroup_cert_file.filename
}

output "apigee_setup_script_executed" {
  value       = var.apigee_install ? "Apigee setup script was triggered via apigee.tf." : "Apigee setup script was skipped."
  description = "Indicates if the Apigee setup script was triggered from apigee.tf."
  depends_on  = [null_resource.apigee_setup_execution] # Ensure output is after execution attempt
}