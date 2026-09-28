# Local runs. CI calls the same terraform commands directly.
#   make apply ENV=dev            all layers in order
#   make plan-base ENV=dev        one layer
#   make destroy ENV=dev          all layers, reverse order
ENV     ?= dev
PROFILE ?= checkout-tf
LAYERS  := iam base network app
REVERSE := app network base iam

ENVDIR = ../../envs/$(ENV)
TF     = AWS_PROFILE=$(PROFILE) terraform -chdir=layers/$*
VARS   = -var-file=$(ENVDIR)/common.tfvars -var-file=$(ENVDIR)/$*.tfvars \
         $(if $(wildcard envs/$(ENV)/$*.local.tfvars),-var-file=$(ENVDIR)/$*.local.tfvars)

.PHONY: plan apply destroy fmt validate test checkov check

init-%:
	$(TF) init -reconfigure -input=false -backend-config=$(ENVDIR)/$*.tfbackend

plan-%: init-%
	$(TF) plan $(VARS)

apply-%: init-%
	$(TF) apply $(VARS)

destroy-%: init-%
	$(TF) destroy $(VARS)

# Later layers read earlier layers' state, so plan only succeeds once those exist.
plan:
	@for l in $(LAYERS); do $(MAKE) --no-print-directory plan-$$l || exit 1; done

apply:
	@for l in $(LAYERS); do $(MAKE) --no-print-directory apply-$$l || exit 1; done

destroy:
	@for l in $(REVERSE); do $(MAKE) --no-print-directory destroy-$$l || exit 1; done

# --- Local checks (no AWS needed) --------------------------------------------

fmt:
	terraform fmt -check -recursive

validate:
	@for d in layers/* modules/* bootstrap; do \
	  echo "== $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; \
	done

test:
	pytest -q

checkov:
	checkov -d . --framework terraform --quiet --compact

check: fmt validate test checkov
