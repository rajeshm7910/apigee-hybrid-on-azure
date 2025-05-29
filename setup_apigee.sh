#!/bin/bash

setup_apigee() {

    local apigee_version=$1
    local apigee_namespace=$2
    local apigee_overrides_yaml_path=$3
    local apigee_service_template_path=$4
    local apigee_sa_key_json_path=$5
    local apigee_envgroup_cert_file_path=$6
    local apigee_envgroup_private_key_file_path=$7

    if [ -z "$apigee_namespace" ]; then
        echo "Apigee namespace is required"
        exit 1
    fi

    if [ -z "$apigee_overrides_yaml_path" ]; then
        echo "Apigee overrides YAML is required"
        exit 1
    fi

    if [ -z "$apigee_sa_key_json_path" ]; then
        echo "Apigee SA key JSON is required"
        exit 1
    fi

    if [ -z "$apigee_envgroup_cert_file_path" ]; then
        echo "Apigee envgroup cert file is required"
        exit 1
    fi

    if [ -z "$apigee_envgroup_private_key_file_path" ]; then
        echo "Apigee envgroup private key file is required"
        exit 1
    fi

    if [ -z "$apigee_service_template_path" ]; then
        echo "Apigee service template path is required"
        exit 1
    fi

    export org_name=$(grep -A 1 'org:' "$apigee_overrides_yaml_path" | grep 'org:' | awk '{print $2}')

    #Check if the apigee_namespace is already set
    # Set up base directories
    export APIGEE_HYBRID_BASE=output/$org_name/apigee-hybrid
    export APIGEE_HELM_CHARTS_BASE=helm-charts

    mkdir -p $APIGEE_HYBRID_BASE/$APIGEE_HELM_CHARTS_BASE

    # Pull Apigee Helm charts
    cd $APIGEE_HYBRID_BASE/$APIGEE_HELM_CHARTS_BASE
    export APIGEE_HELM_CHARTS_HOME=$PWD

    # Set chart repository and version
    export CHART_REPO=oci://us-docker.pkg.dev/apigee-release/apigee-hybrid-helm-charts
    export CHART_VERSION=${apigee_version:-1.14.2-hotfix.1}

    # Pull all required Helm charts
    helm pull $CHART_REPO/apigee-operator --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-datastore --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-env --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-ingress-manager --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-org --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-redis --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-telemetry --version $CHART_VERSION --untar
    helm pull $CHART_REPO/apigee-virtualhost --version $CHART_VERSION --untar

    

    #Get the filename from the path
    local apigee_overrides_yaml_filename=$(basename $apigee_overrides_yaml_path)
    local apigee_service_template_filename=$(basename $apigee_service_template_path)
    local apigee_sa_key_json_filename=$(basename $apigee_sa_key_json_path)
    local apigee_envgroup_cert_file_filename=$(basename $apigee_envgroup_cert_file_path)
    local apigee_envgroup_private_key_file_filename=$(basename $apigee_envgroup_private_key_file_path)

    echo "apigee_overrides_yaml_filename: $apigee_overrides_yaml_filename"
    echo "apigee_sa_key_json_filename: $apigee_sa_key_json_filename"
    echo "apigee_envgroup_cert_file_filename: $apigee_envgroup_cert_file_filename"
    echo "apigee_envgroup_private_key_file_filename: $apigee_envgroup_private_key_file_filename"
    
    
    #Copy the overrides.yaml file to the apigee-hybrid/helm-charts/apigee-operator/templates/overrides.yaml
    cp $apigee_overrides_yaml_path $APIGEE_HELM_CHARTS_HOME/$apigee_overrides_yaml_filename
    cp $apigee_service_template_path $APIGEE_HELM_CHARTS_HOME/$apigee_service_template_filename

    
    #Copy the sa-key.json file to the apigee-hybrid/helm-charts/apigee-operator/templates/sa-key.json
    cp -fr $apigee_sa_key_json_path $APIGEE_HELM_CHARTS_HOME/apigee-datastore/$apigee_sa_key_json_filename
    cp -fr $apigee_sa_key_json_path $APIGEE_HELM_CHARTS_HOME/apigee-telemetry/$apigee_sa_key_json_filename
    cp -fr $apigee_sa_key_json_path $APIGEE_HELM_CHARTS_HOME/apigee-org/$apigee_sa_key_json_filename
    cp -fr $apigee_sa_key_json_path $APIGEE_HELM_CHARTS_HOME/apigee-env/$apigee_sa_key_json_filename


    mkdir -p $APIGEE_HELM_CHARTS_HOME/apigee-virtualhost/certs/

    #Copy the cert file to the apigee-hybrid/helm-charts/apigee-operator/templates/cert.pem
    cp -fr $apigee_envgroup_cert_file_path $APIGEE_HELM_CHARTS_HOME/apigee-virtualhost/certs/$apigee_envgroup_cert_file_filename

    #Copy the private key file to the apigee-hybrid/helm-charts/apigee-operator/templates/key.pem
    cp -fr $apigee_envgroup_private_key_file_path $APIGEE_HELM_CHARTS_HOME/apigee-virtualhost/certs/$apigee_envgroup_private_key_file_filename


}

create_namespace() {
    local apigee_namespace=$1
    if ! kubectl get namespace $apigee_namespace &>/dev/null; then
        kubectl create namespace $apigee_namespace
    fi
}

enable_control_plane_access() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2
    local org_name=$(grep -A 1 'org:' "$apigee_overrides_yaml_path" | grep 'org:' | awk '{print $2}')

    export TOKEN=$(gcloud auth print-access-token)

    curl -X PATCH -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/$org_name/controlPlaneAccess?update_mask=synchronizer_identities" \
    -d "{\"synchronizer_identities\": [\"serviceAccount:apigee-non-prod@$org_name.iam.gserviceaccount.com\"]}"
    
    sleep 5

    curl -X  PATCH -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type:application/json" \
    "https://apigee.googleapis.com/v1/organizations/$org_name/controlPlaneAccess?update_mask=analytics_publisher_identities" \
    -d "{\"analytics_publisher_identities\": [\"serviceAccount:apigee-non-prod@$org_name.iam.gserviceaccount.com\"]}"

}

install_crd() {
    kubectl apply -k  $APIGEE_HELM_CHARTS_HOME/apigee-operator/etc/crds/default/ \
    --server-side \
    --force-conflicts \
    --validate=false
}

install_cert_manager() {
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml
}

install_operator() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade operator apigee-operator/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    -f $apigee_overrides_yaml_path
}

install_datastore() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade datastore apigee-datastore/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    -f $apigee_overrides_yaml_path
}

install_telemetry() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade telemetry apigee-telemetry/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    -f $apigee_overrides_yaml_path
}

install_redis() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade redis apigee-redis/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    -f $apigee_overrides_yaml_path
}

install_ingress_manager() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade ingress-manager apigee-ingress-manager/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    -f $apigee_overrides_yaml_path
}

install_org() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2
    local org_name=$(grep -A 1 'org:' "$apigee_overrides_yaml_path" | grep 'org:' | awk '{print $2}')


    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade $org_name apigee-org/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    -f $apigee_overrides_yaml_path
}

install_env() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    #read the env_name from the overrides.yaml file
    local apigee_env_name=$(grep -A 1 'envs:' "$apigee_overrides_yaml_path" | grep 'name:' | awk '{print $3}')


    local env_release_name="env-release-$apigee_env_name"
    cd $APIGEE_HELM_CHARTS_HOME

    helm upgrade $env_release_name apigee-env/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    --set env=$apigee_env_name \
    -f $apigee_overrides_yaml_path
    
}

install_envgroup() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    #read the env_group_name from the overrides.yaml file
    local apigee_env_group_name=$(grep -A 1 'virtualhosts:' "$apigee_overrides_yaml_path" | grep 'name:' | awk '{print $3}')
    local env_group_release_name="env-group-release-$apigee_env_group_name"

    helm upgrade $env_group_release_name apigee-virtualhost/ \
    --install \
    --namespace $apigee_namespace \
    --atomic \
    --set envgroup=$apigee_env_group_name \
    -f $apigee_overrides_yaml_path
    
}   

setup_ingress() {
    local apigee_namespace=$1
    local apigee_overrides_yaml_path=$2

    cd $APIGEE_HELM_CHARTS_HOME

    #apply the apigee-service.yaml file
    kubectl apply -f $APIGEE_HELM_CHARTS_HOME/apigee-service.yaml
    
}

#main function
main() {

    #$1: apigee_version default: 1.14.2-hotfix.1
    #$2: apigee_namespace name default: apigee
    #$3: apigee_overrides_yaml_path absolute path
    #$4: apigee_service_template_path absolute path
    #$5: apigee_sa_key_json_path absolute path
    #$6: apigee_envgroup_cert_file_path absolute path
    #$7: apigee_envgroup_private_key_file_path absolute path

    setup_apigee $1 $2 $3 $4 $5 $6 $7
    create_namespace $2
    enable_control_plane_access $2 "overrides.yaml"
    install_crd
    install_cert_manager
    install_operator $2 "overrides.yaml"
    install_datastore $2 "overrides.yaml"
    install_telemetry $2 "overrides.yaml"
    install_redis $2 "overrides.yaml"
    install_ingress_manager $2 "overrides.yaml"
    install_org $2 "overrides.yaml"
    install_env $2 "overrides.yaml"
    install_envgroup $2 "overrides.yaml"
    setup_ingress $2 "overrides.yaml"
    
}

main $1 $2 $3 $4 $5 $6 $7 
