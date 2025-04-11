#!/bin/bash
set -e
set -o pipefail

original_args=("$@")

VALUES_FILES=()
CHART_PATH=$2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --values|-f)
      VALUES_FILES+=("$2")
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

OUTPUT=$(mktemp)
npx @cobliteam/flink-state-manager@1.2.4 --values-path "$CHART_PATH"/values.yaml --prod-values-path "${VALUES_FILES[0]}" --context "$HELM_KUBECONTEXT" --menu | tee "$OUTPUT"

# Create a temporary values file
TMP_VALUES=$(mktemp)
echo "
alex-job-chart:
  jobUpgradeMode: savepoint
  jobRestoreFromSavepoint:
    enabled: true
    savepointPath: $(tail -n 1 "$OUTPUT"| cut -d ':' -f 2)
" > "$TMP_VALUES"

# Add your values file to the command
echo "helm upgrade --install "${original_args[@]}" --namespace $HELM_NAMESPACE --kube-context $HELM_KUBECONTEXT --values "$TMP_VALUES""
helm upgrade --install "${original_args[@]}" --namespace $HELM_NAMESPACE --kube-context $HELM_KUBECONTEXT --values "$TMP_VALUES"
