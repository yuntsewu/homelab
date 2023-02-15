# !/usr/bin/env bash

# import env variables from .env file
export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
export $(xargs < .env)

# import script library
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/helper.sh"

# handling variables from .env file
set -a # automatically export all variables
source .env
set +a

cd .. # to project dir, this file should be under ./script

run_ansible_reset_cluster
install_helm_plugins
helmfile apply

# kubectl apply -f apps/external-dns/templates/cloudflare-api-token.yaml --dry-run=client --output=yaml | kubectl apply -f -
kubectl -n argo-cd wait --timeout=60s --for condition=Established \
    crd/applications.argoproj.io \
    crd/applicationsets.argoproj.io
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=argo-cd -n argo-cd
# kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=gitea -n gitea

# TODO: ansible script to baseline this package
ssh $SERVER_IP """
sudo apt install open-iscsi -y && \
sudo systemctl enable open-iscsi &&
sudo systemctl start open-iscsi
"""

# ARGO_CD_HOST="argo-cd.app.domain.com"
ARGO_CD_HOST="192.168.x.x"
ARGO_USER="admin"
ARGO_PASSWORD=$(kubectl -n argo-cd get secrets argocd-initial-admin-secret --template={{.data.password}} | base64 -d)
chmod 600 ~/.config/argocd/config
argocd login $ARGO_CD_HOST --username $ARGO_USER --password $ARGO_PASSWORD --plaintext
argocd repo add git@github.com:yuntsewu/cosmos.git --ssh-private-key-path ~/.ssh/id_rsa
# ssh-keyscan gitea.app.domain.com | argocd cert add-ssh --batch 
# argocd repo add git@github.com:yuntsewu/cosmos.git --ssh-private-key-path ~/.ssh/id_rsa --grpc-web
# 2. create root stack of apps
helm template \
    --include-crds \
    --namespace argo-cd \
    --values platform-bootstrap/root/values.yaml \
    argo-cd platform-bootstrap/root \
    | kubectl apply -n argo-cd -f -
