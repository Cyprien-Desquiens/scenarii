ENC_PROJECT := "sbx-cde"
ENC_LOCATION := "europe-west3"
ENC_KEYRING := "cde-keyring"
ENC_KEY := "cde-secret-key"
GCP_PROJECT := "sbx-cde"
GCP_ZONE := "europe-west3-a"
K8S_CLUSTER := "scenari"
REGISTRY_DOMAIN := "europe-docker.pkg.dev"
REGISTRY_NAME := REGISTRY_DOMAIN + "/valiuz/charts"

# List available recipes
list:
    just --list


# Decrypt given ENC_FILE.
@decrypt ENC_FILE:
    #!/usr/bin/env bash
    ENC_FILE="{{ENC_FILE}}"
    FILE=$(echo ${ENC_FILE%%.enc})
    echo "Decrypt {{ENC_FILE}} to ${FILE}"
    gcloud kms decrypt \
        --project {{ENC_PROJECT}} \
        --location {{ENC_LOCATION}} \
        --keyring {{ENC_KEYRING}} \
        --key {{ENC_KEY}} \
        --plaintext-file $FILE \
        --ciphertext-file $ENC_FILE

# Decrypt all .enc files in project.
@decrypt_all:
    #!/usr/bin/env bash
    shopt -s globstar
    for ENC_FILE in $(ls **/*.*.enc); do
        FILE=$(echo ${ENC_FILE%%.enc})
        echo "Decrypt $ENC_FILE to $FILE";
        gcloud kms decrypt \
            --project {{ENC_PROJECT}} \
            --location {{ENC_LOCATION}} \
            --keyring {{ENC_KEYRING}} \
            --key {{ENC_KEY}} \
            --plaintext-file $FILE \
            --ciphertext-file $ENC_FILE
    done

# Encrypt given FILE.
@encrypt FILE:
    echo "Encrypt {{FILE}}";
    gcloud kms encrypt \
        --project {{ENC_PROJECT}} \
        --location {{ENC_LOCATION}} \
        --keyring {{ENC_KEYRING}} \
        --key {{ENC_KEY}} \
        --plaintext-file {{FILE}} \
        --ciphertext-file {{FILE}}.enc

# Edit the given encrypted FILE
@sops_edit FILE:
    sops {{FILE}}

# Encrypt the given FILE
@sops_encrypt FILE:
    echo "Sops encryption for {{FILE}}"
    sops -e -i {{FILE}} || true

# Decrypt the given FILE
@sops_decrypt FILE:
    echo "Sops decryption for {{FILE}}"
    sops -d -i {{FILE}} || true

# Rotate the key for the given FILE
@sops_rotate FILE:
    echo "Sops rotation for {{FILE}}"
    sops -r -i {{FILE}} || true

# Encrypt all files in DIR
@sops_encrypt_dir DIR:
    echo "Sops encryption for {{DIR}}"
    ls {{DIR}}/* | xargs -I % sops -e -i % || true

# Decrypt all files in DIR
@sops_decrypt_dir DIR:
    echo "Sops decryption for {{DIR}}"
    ls {{DIR}}/* | xargs -I % sops -d -i % || true

# Rotate the key for all files in DIR
@sops_rotate_dir DIR:
    echo "Sops rotation for {{DIR}}"
    dir {{DIR}}/* | xargs -I % sops -r -i % || true


# Traefik Deployment (installation)
@traefik_deploy:
    echo "Create Traefik Namespace";
    kubectl create namespace traefik;
    echo "Deploy Traefik";
    helm install valiuz-traefik \
        ./traefik/helm/ \
        --namespace traefik \
        --values ./traefik/environments/custom-values.yaml;

# Traefik Upgrade
@traefik_upgrade:
    echo "Upgrade Traefik";
    helm upgrade valiuz-traefik \
        ./traefik/helm/ \
        --namespace traefik \
        --values ./traefik/environments/custom-values.yaml;

# Traefik Removal
@traefik_remove:
    echo "Delete Traefik";
    helm uninstall valiuz-traefik \
        --namespace traefik;

# Traefik SSL Certificates deployment
@traefik_ssl_deploy:
    kubectl create secret tls valiuz-io-tls \
      --cert ./kubernetes/certificates/valiuz-io.crt \
      --key ./kubernetes/certificates/valiuz-io.key \
      -n traefik  \
      || echo "Certificate already exists";

# Treafik SSL Certificates Removal
@traefik_ssl_remove:
    kubectl delete secret valiuz-io-tls \
      -n traefik;

# Traefik IngressRoute Deployment
@traefik_ingressroute_deploy:
    kubectl apply -f "./traefik/ingressRoutes/";

# Traefik IngressRoute Removal
@traefik_ingressroute_remove:
    kubectl delete -f "./traefik/ingressRoutes/";

# Metabase Deployment
@metabase_deploy:
    kubectl create namespace metabase || echo "Namespace already exists";
    kubectl apply -f "./metabase/" -R;

# Metabase Removal
@metabase_remove:
    kubectl delete -f "./metabase/" -R;
    kubectl delete namespace metabase;


# Kubernetes Cluster State Check
@kubernetes_cluster_state:
    #!/usr/bin/env bash
    echo "--- :gcloud: Verifying cluster state";
    if [[ $(gcloud container clusters describe {{K8S_CLUSTER}} --project={{GCP_PROJECT}} --zone={{GCP_ZONE}} --format json | jq -r ".status") != "RUNNING" ]]; then
        echo "Cluster is not in safe running state"
        sleep 60
    else
        echo "Cluster is running"
    fi

# Kubernetes Cluster Get Context
@kubernetes_cluster_get_context:
    gcloud container clusters get-credentials {{K8S_CLUSTER}} \
      --zone={{GCP_ZONE}} \
      --project={{GCP_PROJECT}};

# Kubernetes Basics Deployment
@kubernetes_basics_deploy:
    kubectl apply -f "./kubernetes/manifests/";

# Kubernetes Basics Removal
@kubernetes_basics_remove:
    kubectl delete -f "./kubernetes/manifests/";


@helm_login:
    gcloud auth application-default print-access-token | \
        helm registry login -u oauth2accesstoken --password-stdin https://{{REGISTRY_DOMAIN}}

# Kubernetes All Services Deployment
@kubernetes_all_deploy:
    just decrypt_all;
    just kubernetes_cluster_get_context;
    just kubernetes_cluster_state;
    just metabase_deploy;
    just traefik_upgrade;
    just traefik_ssl_deploy;
    just traefik_ingressroute_deploy;

# Do the helm ACTION for the given ENV.
@wiz_helm ACTION="upgrade":
    helm {{ACTION}} wiz-admission-controller \
        wiz-sec/wiz-admission-controller \
        --version 3.3.2 \
        --namespace {{KUBE_WIZ_NAMESPACE}} \
        --values "wiz/values.yaml"
    echo "Wiz helm chart {{ACTION}} succeeded"

# Do a helm upgrade in dry-run for the given ENV.
@wiz_helm_dry ACTION="upgrade":
    helm {{ACTION}} wiz-admission-controller --dry-run \
        wiz-sec/wiz-admission-controller \
        --version 3.3.2 \
        --namespace {{KUBE_WIZ_NAMESPACE}} \
        --values "wiz/values.yaml"

# Github Runner: Deploy specific product runner
@arc_runner_deploy PRODUCT:
    just helm_login;
    helm upgrade --install \
        {{PRODUCT}}-runners \
        oci://europe-docker.pkg.dev/valiuz/charts/valiuz-github-runner \
        --version 0.6.0 \
        --namespace github \
        --create-namespace \
        --values ./github/runner/{{PRODUCT}}.yaml;


# Github Runner WLI set binding
@arc_runner_wli PRODUCT:
    gcloud iam service-accounts add-iam-policy-binding wli-github-{{PRODUCT}}@valiuz-devops.iam.gserviceaccount.com \
        --role roles/iam.workloadIdentityUser \
        --member "serviceAccount:valiuz-devops.svc.id.goog[github/{{PRODUCT}}]" \
        --project "valiuz-devops" ;