location="eastus" # Change this to the location you want to deploy to
resource_group_name_prefix="apigee"
system_pool_node_count=1
runtime_pool_min_count=1
runtime_pool_max_count=2
runtime_pool_enable_autoscaling=false
runtime_pool_node_count=2 #Required if autoscale is false
data_pool_min_count=1
data_pool_max_count=1
data_pool_enable_autoscaling=false
data_pool_node_count=1 #Required if autoscale is false
kubernetes_version = "1.31"

#### GCP/Apigee Specific variables ####

project_id="apigee-gke-example3" # Replace with your GCP project ID
apigee_env_name="dev" # Replace with your Apigee environment name
apigee_envgroup_name="api-proxy-group" # Replace with your Apigee environment group name
apigee_envgroup_hostnames=["api.example.com"] 
apigee_version="1.14.2-hotfix.1" # Specify your target Apigee version
apigee_namespace="apigee"
ingress_name="apigee-ingress"
apigee_cassandra_replica_count=1
ingress_svc_annotations={}
billing_type="EVALUATION"
apigee_install=true # or false
create_org=true
