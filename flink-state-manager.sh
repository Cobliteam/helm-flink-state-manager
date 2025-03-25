#!/bin/bash
set -e
set -o pipefail

original_args=("$@")

VALUES_FILES=()
CONTEXT="cobli-prod-devices"
CHART_PATH=$2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --values|-f)
      VALUES_FILES+=("$2")
      shift 2
      ;;
    --kube-context)
      CONTEXT+=("$2")
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

OUTPUT=$(mktemp)
npx @cobliteam/flink-state-manager@1.1.1 --values-path $CHART_PATH/values.yaml --prod-values-path ${VALUES_FILES[0]} --context $CONTEXT --menu | tee $OUTPUT

cat $OUTPUT

# Create a temporary values file
TMP_VALUES=$(mktemp)
echo "
alex-job-chart:
  jobUpgradeMode: savepoint
  jobRestoreFromSavepoint:
    enabled: true
    savepointPath: $(tail -n 1 $OUTPUT| cut -d ':' -f 2)
" > "$TMP_VALUES"

# Add your values file to the command
helm upgrade --install ${original_args[@]} --values $TMP_VALUES
