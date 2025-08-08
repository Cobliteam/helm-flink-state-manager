#!/bin/bash
set -e
set -o pipefail

original_args=("$@")

VALUES_FILES=()
CHART_PATH=$2

while [[ $# -gt 0 ]]; do
  case "$1" in
  --values | -f)
    VALUES_FILES+=("$2")
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done

# Ask user whether to restore from a checkpoint or a savepoint using a selector

PS3="Select restore mode: "
select RESTORE_MODE in "From a checkpoint" "From a savepoint"; do
  case $RESTORE_MODE in
  "From a checkpoint" | "From a savepoint")
    break
    ;;
  *)
    echo "Invalid option. Please select 1 or 2."
    ;;
  esac
done

OUTPUT=$(mktemp)
if [[ "$RESTORE_MODE" == "From a checkpoint" ]]; then
  npx @cobliteam/flink-state-manager@1.4.1 --values-path "$CHART_PATH"/values.yaml --prod-values-path "${VALUES_FILES[0]}" --context "$HELM_KUBECONTEXT" --menu --checkpoints | tee "$OUTPUT"
else
  npx @cobliteam/flink-state-manager@1.4.1 --values-path "$CHART_PATH"/values.yaml --prod-values-path "${VALUES_FILES[0]}" --context "$HELM_KUBECONTEXT" --menu | tee "$OUTPUT"
fi

# Create a temporary values file. This entry can receive either a savepoint or a
# checkpoint path.
TMP_VALUES=$(mktemp)
echo "
alex-job-chart:
  jobUpgradeMode: savepoint
  jobRestoreFromSavepoint:
    enabled: true
    savepointPath: $(tail -n 1 "$OUTPUT" | cut -d ':' -f 2)
" >"$TMP_VALUES"

# Add your values file to the command
echo
echo "helm upgrade --install \"${original_args[@]}\" --namespace $HELM_NAMESPACE --kube-context $HELM_KUBECONTEXT --values \"$TMP_VALUES\""
helm upgrade --install "${original_args[@]}" --namespace $HELM_NAMESPACE --kube-context $HELM_KUBECONTEXT --values "$TMP_VALUES"
