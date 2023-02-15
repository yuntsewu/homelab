# !/usr/bin/env bash
function install_helm_plugins() {
    if helm plugin list | grep -q 'diff'; then
        echo "Helm plugin - helm-diff installed! skipping..."
    else
        echo "Helm plugin - helm-diff not installed! installing..."
        helm plugin install https://github.com/databus23/helm-diff
    fi
}

function run_ansible_reset_cluster() {
    cd metal
    sed -i "1 a $SERVER_IP" inventory/lab/hosts.ini
    ansible-playbook reset.yml -i inventory/lab/hosts.ini
    ssh $SERVER_IP "sudo reboot"
    while ! $(ssh $SERVER_IP /bin/true)
    do
        echo "checking in 15 seconds..."
        sleep 15
        echo "Trying again..."
    done
    # ssh -o visualhostkey=yes -o FingerprintHash=md5 $SERVER_IP
    ansible-playbook site.yml -i inventory/lab/hosts.ini
    ssh $SERVER_IP "sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/$SERVER_IP/g'" > $KUBECONFIG
}

function verify_cloudflare_key() {
    echo "verify api key to cloudflare"
    curl -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}" \
        --header "Content-Type:application/json" \
        --header "Authorization: Bearer ${CF_API_TOKEN}" | jq
}

function apply_cloudflare_key() {
    cat << EOF | kubectl apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: kube-system
type: Opaque
stringData:
  api-token: ${CF_API_TOKEN}
EOF
}

function install_letsencrypt_cluster_issuer() {
    cat << EOF | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${CF_API_EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
}

function finalize_namespaces() {
  # delete stuck ns
  export NAMESPACE
  kubectl proxy &
  kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
  curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
}