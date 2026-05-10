#!/usr/bin/env bash
# deploy.sh — Fabric IQ local deployment (Linux / macOS)
#
# Runs terraform init/apply for infrastructure, prepares data, and optionally
# uploads data files to blob storage.
#
# Prerequisites:
#   - Azure CLI logged in:  az login
#   - Terraform installed:  https://developer.hashicorp.com/terraform/install
#   - Python 3.9+:          python --version
#
# Usage:
#   bash scripts/deploy.sh --subscription <SUBSCRIPTION_ID> [--apply] [--upload-data]
#
# Options:
#   --subscription  <ID>   Azure subscription ID (required)
#   --apply                Run terraform apply (default: plan only)
#   --upload-data          Upload data files to blob storage after apply

set -euo pipefail

# ── Argument parsing ─────────────────────────────────────────────────────────

SUBSCRIPTION_ID=""
RUN_APPLY=false
UPLOAD_DATA=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --subscription) SUBSCRIPTION_ID="$2"; shift 2 ;;
        --apply)        RUN_APPLY=true;        shift   ;;
        --upload-data)  UPLOAD_DATA=true;      shift   ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SUBSCRIPTION_ID" ]]; then
    echo "Error: --subscription <ID> is required"
    echo "Usage: bash scripts/deploy.sh --subscription <SUBSCRIPTION_ID> [--apply] [--upload-data]"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"
VAR_FILE="$REPO_ROOT/config/terraform.tfvars.json"

# ── Colour helpers ───────────────────────────────────────────────────────────

info()  { echo "[->] $*"; }
ok()    { echo "[OK] $*"; }
warn()  { echo "[!!] $*"; }
err()   { echo "[XX] $*" >&2; }

# ── Step 1: Prerequisites ────────────────────────────────────────────────────

info "Checking prerequisites..."

for tool in az terraform python; do
    if command -v "$tool" &>/dev/null; then
        ok "$tool found: $($tool --version 2>&1 | head -1)"
    else
        err "$tool not found — please install it before running this script"
        exit 1
    fi
done

# ── Step 2: Azure login check ────────────────────────────────────────────────

info "Setting Azure subscription to $SUBSCRIPTION_ID..."
az account set --subscription "$SUBSCRIPTION_ID"
ok "Subscription set"

# ── Step 3: Data preparation ─────────────────────────────────────────────────

info "Running data preparation script..."
if python -c "import pandas" &>/dev/null; then
    python "$REPO_ROOT/scripts/populate_fabric_complete.py"
    ok "Data preparation complete"
else
    warn "pandas not installed — skipping data preparation (run: pip install pandas)"
fi

# ── Step 4: Terraform ─────────────────────────────────────────────────────────

info "Initialising Terraform..."
terraform -chdir="$TF_DIR" init

info "Running Terraform plan..."
terraform -chdir="$TF_DIR" plan \
    -var-file="$VAR_FILE" \
    -out="$TF_DIR/tfplan"
ok "Terraform plan complete — review the output above"

if [[ "$RUN_APPLY" == true ]]; then
    info "Applying Terraform plan..."
    terraform -chdir="$TF_DIR" apply "$TF_DIR/tfplan"
    ok "Terraform apply complete"
    rm -f "$TF_DIR/tfplan"
else
    warn "Dry-run only. Pass --apply to provision infrastructure."
fi

# ── Step 5: Data upload ───────────────────────────────────────────────────────

if [[ "$UPLOAD_DATA" == true && "$RUN_APPLY" == true ]]; then
    info "Uploading data files to Azure Blob Storage..."

    STORAGE_ACCOUNT=$(jq -r '.storage_account_name' "$VAR_FILE")
    CONTAINER=$(jq -r '.raw_container_name' "$VAR_FILE")

    for f in employees.json digital_assets.json contributions.json projects.json \
              org_hierarchy.json emails.json; do
        SRC="$REPO_ROOT/data/$f"
        if [[ -f "$SRC" ]]; then
            az storage blob upload \
                --account-name "$STORAGE_ACCOUNT" \
                --container-name "$CONTAINER" \
                --name "$f" \
                --file "$SRC" \
                --overwrite \
                --auth-mode login \
                --output none
            ok "Uploaded $f"
        else
            warn "$f not found — skipping"
        fi
    done
elif [[ "$UPLOAD_DATA" == true ]]; then
    warn "Skipping data upload — requires --apply to be set as well"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "=============================="
echo " Deployment summary"
echo "=============================="
if [[ "$RUN_APPLY" == true ]]; then
    ok "Terraform infrastructure applied"
    API_NAME=$(jq -r '.api_app_service_name' "$VAR_FILE")
    UI_NAME=$(jq -r '.ui_app_service_name' "$VAR_FILE")
    echo ""
    echo "  API:  https://${API_NAME}.azurewebsites.net/health"
    echo "  UI:   https://${UI_NAME}.azurewebsites.net"
    echo "  Docs: https://${API_NAME}.azurewebsites.net/docs"
else
    warn "Infrastructure not applied (plan only)"
    echo ""
    echo "  Re-run with --apply to provision:"
    echo "  bash scripts/deploy.sh --subscription $SUBSCRIPTION_ID --apply"
fi
echo ""
echo "  For full CI/CD deployment, push to main or trigger the"
echo "  'Deploy Infrastructure and Artifacts' workflow in GitHub Actions."
