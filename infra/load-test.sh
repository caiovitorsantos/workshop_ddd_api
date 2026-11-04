#!/usr/bin/env bash
# Drives the HPA demo: generates load from inside the cluster against the order
# listing (authenticated, hits Rails and PostgreSQL) and prints the HPA while it
# runs. Load comes from a pod, not this machine: no laptop bandwidth, no ELB in
# the way, and the password never travels over the ELB's plain HTTP.
#
#   infra/load-test.sh                 # 3 min, 8 parallel clients
#   DURATION=300 WORKERS=12 infra/load-test.sh
#
# In other terminals, for the video:
#   kubectl -n oficina get hpa -w
#   kubectl -n oficina get pods -l app=oficina-api -w
#
# The manager's password is read from ~/.config/oficina-api/admin_password and
# reaches the pod through a throwaway Secret, never through argv or the pod spec.
set -euo pipefail

NAMESPACE=oficina
DURATION=${DURATION:-180}
WORKERS=${WORKERS:-8}
PASSWORD_FILE=${PASSWORD_FILE:-$HOME/.config/oficina-api/admin_password}
EMAIL=${EMAIL:-gerente@oficina.local}

[[ -r $PASSWORD_FILE ]] || { echo "senha não encontrada em $PASSWORD_FILE" >&2; exit 1; }

cleanup() {
  kubectl -n "$NAMESPACE" delete pod oficina-load --ignore-not-found --wait=false >/dev/null
  kubectl -n "$NAMESPACE" delete secret oficina-load --ignore-not-found >/dev/null
}
trap cleanup EXIT
cleanup

kubectl -n "$NAMESPACE" create secret generic oficina-load \
  --from-literal=email="$EMAIL" --from-file=password="$PASSWORD_FILE" >/dev/null

kubectl -n "$NAMESPACE" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: oficina-load
spec:
  restartPolicy: Never
  containers:
    - name: load
      image: curlimages/curl:8.11.1
      envFrom:
        - secretRef:
            name: oficina-load
      command: ["sh", "-c"]
      args:
        - |
          api=http://oficina-api
          token=\$(curl -sf "\$api/api/v1/session" --data-urlencode "email=\$email" \
            --data-urlencode "password=\$password" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
          [ -n "\$token" ] || { echo "login falhou"; exit 1; }
          end=\$(( \$(date +%s) + $DURATION ))
          for w in \$(seq $WORKERS); do
            while [ \$(date +%s) -lt \$end ]; do
              curl -s -o /dev/null -H "Authorization: Bearer \$token" "\$api/api/v1/service_orders"
            done &
          done
          wait
          echo "carga encerrada"
YAML

kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/oficina-load --timeout=120s >/dev/null
echo "Carga: $WORKERS clientes por ${DURATION}s contra GET /api/v1/service_orders"

end=$(( $(date +%s) + DURATION ))
while (( $(date +%s) < end )); do
  phase=$(kubectl -n "$NAMESPACE" get pod oficina-load -o jsonpath='{.status.phase}')
  if [[ $phase == Failed ]]; then kubectl -n "$NAMESPACE" logs oficina-load >&2; exit 1; fi
  printf '%s  ' "$(date +%T)"
  kubectl -n "$NAMESPACE" get hpa oficina-api --no-headers
  sleep 15
done

echo "Carga encerrada. O HPA volta a 2 réplicas em ~5 min (janela de estabilização):"
echo "  kubectl -n $NAMESPACE get hpa -w"
