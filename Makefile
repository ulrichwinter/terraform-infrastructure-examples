REGION="eu-central-1"

clean: ## Clean local terraform folder and plan file
	rm -fR .terraform
	rm -f ${ENV}.tfplan

check-env: ## Check ENV setup exists
	@if [ -z $(ENV) ]; then \
		echo "set variable ENV and try again"; \
		echo "Example usage: \`ENV=demo make plan\`"; \
		exit 1; \
	 fi

init: check-env clean ## Initialize backend configuration
	terraform init --var-file=${ENV}.tfvars -backend-config=${ENV}.backend
	tflint --init

lint: check-env ## Check terraform code with tflint
	terraform fmt -recursive
	result=$(tflint --module --var-file=${ENV}.tfvars --config .tflint.hcl)

audit: check-env ## Check terraform code for vulnerabilities using tfsec
	tfsec -s --tfvars-file=${ENV}.tfvars

plan: check-env ## Create terraform plan
	terraform get -update
	terraform plan --var-file=${ENV}.tfvars -out=${ENV}.tfplan

apply: check-env ## Apply terraform code
	terraform get -update
	terraform apply --var-file=${ENV}.tfvars

apply-plan: check-env ## Apply terraform code using existing plan file
	terraform apply ${ENV}.tfplan

destroy: check-env ## Destroy terraform resources
	terraform destroy --var-file=${ENV}.tfvars

help: ## Help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
