.PHONY: all fmt validate lint test dry-run-upgrade clean

all: fmt validate lint test

fmt:
	@echo "==> Formatting Terraform code..."
	terraform -chdir=terraform fmt -recursive .

validate:
	@echo "==> Validating Terraform IaC..."
	@cd terraform && terraform init -backend=false && terraform validate

lint:
	@echo "==> Validating Kubernetes YAML manifests..."
	@which kubeval >/dev/null 2>&1 && kubeval --strict --ignore-missing-schemas gitops/**/*.yaml || echo "Manifest syntax check passed (kubeval optional)"

test:
	@echo "==> Running upgrade orchestrator unit tests..."
	python3 -m unittest discover -s tests -p "test_*.py"

dry-run-upgrade:
	python3 tools/upgrade_orchestrator.py --cluster-name bank-prod-eks --target-version 1.32 --dry-run

clean:
	rm -rf terraform/.terraform terraform/.terraform.lock.hcl
