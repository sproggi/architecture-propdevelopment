#!/bin/bash
set -e

# Путь к CA Minikube
CA_CRT="$HOME/.minikube/ca.crt"
CA_KEY="$HOME/.minikube/ca.key"
KUBECONFIG_DIR="./kubeconfigs"
mkdir -p "$KUBECONFIG_DIR"

function create_user() {
  local USER=$1
  local GROUP=$2

  # Генерация приватного ключа
  openssl genrsa -out "${USER}.key" 2048

  # Создание CSR
  cat > "${USER}.csr" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectAltName = email:${USER}@example.com
EOF

  # Подпись CSR
  openssl req -new -key "${USER}.key" -out "${USER}.csr" -subj "/CN=${USER}/O=${GROUP}" -config "${USER}.csr"

  # Подпись сертификата CA Minikube
  openssl x509 -req -in "${USER}.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out "${USER}.crt" -days 365

  # Формирование kubeconfig
  kubectl config set-cluster minikube --server=https://$(minikube ip):8443 --certificate-authority="$CA_CRT" --embed-certs=true --kubeconfig="${KUBECONFIG_DIR}/${USER}-config"
  kubectl config set-credentials "${USER}" --client-certificate="${USER}.crt" --client-key="${USER}.key" --embed-certs=true --kubeconfig="${KUBECONFIG_DIR}/${USER}-config"
  kubectl config set-context minikube --cluster=minikube --user="${USER}" --kubeconfig="${KUBECONFIG_DIR}/${USER}-config"
  kubectl config use-context minikube --kubeconfig="${KUBECONFIG_DIR}/${USER}-config"

  echo "Пользователь ${USER} (группа ${GROUP}) создан. Конфиг: ${KUBECONFIG_DIR}/${USER}-config"
}

create_user "dev-user" "developers"
create_user "sre-user" "sre-team"

echo "Готово. Для проверки: kubectl --kubeconfig=./kubeconfigs/dev-user-config get pods"