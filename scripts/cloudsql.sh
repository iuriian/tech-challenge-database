#!/usr/bin/env bash
#
# Uso: ./scripts/cloudsql.sh {on|off|status|tunnel}
# Variaveis opcionais: GCP_PROJECT_ID, INSTANCE, NAMESPACE, LOCAL_PORT
#
set -euo pipefail

PROJECT="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
INSTANCE="${INSTANCE:-tech-challenge-staging-pg}"
NAMESPACE="${NAMESPACE:-tech-challenge-staging}"
LOCAL_PORT="${LOCAL_PORT:-5433}"
TUNNEL_POD="cloudsql-tunnel"

[[ -n "$PROJECT" ]] || { echo "ERRO: defina GCP_PROJECT_ID" >&2; exit 1; }

case "${1:-}" in
  on)
    gcloud sql instances patch "$INSTANCE" --project "$PROJECT" --activation-policy=ALWAYS --quiet ;;
  off)
    gcloud sql instances patch "$INSTANCE" --project "$PROJECT" --activation-policy=NEVER --quiet ;;
  status)
    gcloud sql instances describe "$INSTANCE" --project "$PROJECT" \
      --format="table(name,state,settings.activationPolicy,settings.tier,ipAddresses[0].ipAddress)" ;;
  tunnel)
    # Sem IP publico: o tunel passa por um pod no GKE. Requer cluster e instancia ligados.
    IP=$(gcloud sql instances describe "$INSTANCE" --project "$PROJECT" \
      --format="value(ipAddresses[0].ipAddress)")
    kubectl delete pod "$TUNNEL_POD" -n "$NAMESPACE" --ignore-not-found >/dev/null
    kubectl run "$TUNNEL_POD" -n "$NAMESPACE" --image=alpine/socat --restart=Never -- \
      tcp-listen:5432,fork,reuseaddr "tcp-connect:${IP}:5432"
    trap 'kubectl delete pod "$TUNNEL_POD" -n "$NAMESPACE" --ignore-not-found >/dev/null' EXIT
    kubectl wait --for=condition=Ready "pod/$TUNNEL_POD" -n "$NAMESPACE" --timeout=120s
    echo "Conecte em localhost:${LOCAL_PORT} (sslmode=require). App local: SPRING_FLYWAY_ENABLED=false"
    kubectl port-forward -n "$NAMESPACE" "pod/$TUNNEL_POD" "${LOCAL_PORT}:5432" ;;
  *)
    sed -n '2,4p' "$0"; exit 1 ;;
esac