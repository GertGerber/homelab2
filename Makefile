# ─────────────────────────────────────────────────────────────
# Project: homelab2
# Tailored Makefile wired to your repo structure
# - Focus: scripts + Ansible today
# - Keep: Packer/Terraform scaffolding for later
# ─────────────────────────────────────────────────────────────

# ------------------------------------------------------------
# Project-wide settings
# ------------------------------------------------------------

# Use bash as the shell and fail fast on errors.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

# Default target if you just run `make`
.DEFAULT_GOAL := help

# Project paths (change these to match your layout)
PROJECT_DIR             ?= $HOME/Github/homelab2
# where your bash scripts live
SCRIPTS_DIR      ?= scripts
# optional folder for python code
PY_DIR                  ?= python
# where your ansible live
ANSIBLE_DIR      ?= ansible
# main ansible playbook
ANSIBLE_PLAYBOOK        ?= site.yml
# ansible inventory
ANSIBLE_INV             ?= $ANSIBLE_DIR/inventories/production/hosts.yml
# main packer file
PACKER_FILE             ?= packer.pkr.hcl 
# optional e.g. packer.auto.pkrvars.hcl
PACKER_VAR_FILE         ?= 
# terraform working directory
TF_DIR           ?= terraform 
# optional e.g. terraform.tfvars
TF_VAR_FILE      ?= 

# Python virtual environment location and interpreter
VENV_DIR ?= .venv
PYTHON   ?= python3
PIP      ?= $(VENV_DIR)/bin/pip
PY       ?= $(VENV_DIR)/bin/python

# Optional .env file for environment variables
ENV_FILE ?= .env

# Load variables from .env if it exists (safe: ignores if missing)
ifneq (,$(wildcard $(ENV_FILE)))
include $(ENV_FILE)
export
endif

# Declare phony targets (not real files)
.PHONY: help bootstrap init env bash py ansible packer-init packer-build tf-init tf-plan tf-apply tf-destroy tf-fmt tf-validate clean

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

## Show available commands (this screen)
help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	/^[a-zA-Z0-9_.-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
	/^# ----/ {print ""} ' $(MAKEFILE_LIST)

# ------------------------------------------------------------
# One-time & environment setup
# ------------------------------------------------------------
## Bootstrap localhost (DevOps) by running scripts in $(SCRIPTS_DIR)
bootstrap: ## Run bootstrap scripts for your DevOps workstation
	@script="$(SCRIPTS_DIR)/01_sh_executable.sh"; \
	if [ ! -f "$$script" ]; then \
		echo "Missing $$script"; exit 2; \
	fi; \
	echo "[bootstrap] Executing $$script"; \
	chmod +x "$$script" || true; \
	"$$script"
	# To chain more bootstrap steps later, uncomment and ensure they exist:
	@$(SCRIPTS_DIR)/02_install_tools.sh
	@$(SCRIPTS_DIR)/04_config_git_gh.sh


## Create Python venv and install local dependencies if requirements.txt exists
init: env ## Bootstrap local tooling (venv, pip, packer/terraform init if files present)
        # Python
	@if [ -f $(PY_DIR)/requirements.txt ]; then \
		echo "[init] Installing Python deps from requirements.txt"; \
		$(PIP) install -r $(PY_DIR)/requirements.txt; \
	else \
		echo "[init] No requirements.txt found; skipping Python deps"; \
	fi
        # Ansible
	@if [ -f $(ANSIBLE_DIR)/requirements.yml ]; then \
		echo "[init] Installing Ansible roles/collections from requirements.yml"; \
		ansible-galaxy install -r $(ANSIBLE_DIR)/requirements.yml; \
	else \
		echo "[init] No Ansible requirements.yml; skipping"; \
	fi
        # Terraform
	@if [ -d "$(TF_DIR)" ]; then \
		echo "[init] Running terraform init in $(TF_DIR)"; \
		terraform -chdir=$(TF_DIR) init -upgrade; \
	else \
		echo "[init] No $(TF_DIR) directory; skipping terraform init"; \
	fi
        #Packer
	@if [ -f "$(PACKER_FILE)" ]; then \
		echo "[init] Running packer init"; \
		packer init $(PACKER_FILE); \
	else \
		echo "[init] No $(PACKER_FILE); skipping packer init"; \
	fi

## Create/refresh Python virtual environment
env:
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "[env] Creating venv in $(VENV_DIR)"; \
		$(PYTHON) -m venv $(VENV_DIR); \
	else \
		echo "[env] Using existing venv at $(VENV_DIR)"; \
	fi
	@echo "[env] Python: $$($(PY) -V)"

# ------------------------------------------------------------
# Bash scripts
# ------------------------------------------------------------

## Run a bash script: make bash SCRIPT=path/to/script.sh ARGS="--flag value"
bash: ## Run a bash script in $(SCRIPTS_DIR) or a given path (use SCRIPT=)
	@if [ -z "$$SCRIPT" ]; then \
		echo "Usage: make bash SCRIPT=path/to/script.sh ARGS=\"...\""; exit 2; \
	fi
	@echo "[bash] Executing $$SCRIPT $$ARGS"
	@chmod +x "$$SCRIPT" || true
	@"$$SCRIPT" $$ARGS

# ------------------------------------------------------------
# Python code
# ------------------------------------------------------------

## Run a Python file with the project venv: make py FILE=app.py ARGS="--foo bar"
py: env ## Run a Python file within the virtual environment (use FILE=)
	@if [ -z "$$FILE" ]; then \
		echo "Usage: make py FILE=$(PY_DIR)/script.py ARGS=\"...\""; exit 2; \
	fi
	@echo "[py] $(PY) $$FILE $$ARGS"
	@$(PY) "$$FILE" $$ARGS

# ------------------------------------------------------------
# Ansible
# ------------------------------------------------------------

## Run the main Ansible playbook: make ansible EXTRA="-t tag1,tag2 -e var=value"
ansible: ## Execute Ansible playbook with inventory and optional EXTRA flags
	@if [ ! -f "$(ANSIBLE_PLAYBOOK)" ]; then \
		echo "Missing $(ANSIBLE_PLAYBOOK)"; exit 2; \
	fi
	@if [ ! -f "$(ANSIBLE_INV)" ]; then \
		echo "Missing $(ANSIBLE_INV)"; exit 2; \
	fi
	@echo "[ansible] ansible-playbook -i $(ANSIBLE_INV) $(ANSIBLE_PLAYBOOK) $(EXTRA)"
	@ansible-playbook -i "$(ANSIBLE_INV)" "$(ANSIBLE_PLAYBOOK)" $(EXTRA)

# ------------------------------------------------------------
# Packer
# ------------------------------------------------------------

## Initialize Packer modules/plugins
packer-init: ## Run packer init on $(PACKER_FILE)
	@if [ ! -f "$(PACKER_FILE)" ]; then echo "Missing $(PACKER_FILE)"; exit 2; fi
	@echo "[packer] packer init $(PACKER_FILE)"
	@packer init "$(PACKER_FILE)"

## Build with Packer: make packer-build PACKER_VAR_FILE=vars.pkrvars.hcl
packer-build: ## Run packer build (supports PACKER_VAR_FILE and PACKER_ONLY)
	@if [ ! -f "$(PACKER_FILE)" ]; then echo "Missing $(PACKER_FILE)"; exit 2; fi
	@CMD="packer build"; \
	if [ -n "$(PACKER_VAR_FILE)" ]; then CMD="$$CMD -var-file=$(PACKER_VAR_FILE)"; fi; \
	if [ -n "$(PACKER_ONLY)" ]; then CMD="$$CMD -only=$(PACKER_ONLY)"; fi; \
	CMD="$$CMD $(PACKER_FILE)"; \
	echo "[packer] $$CMD"; \
	eval $$CMD

# ------------------------------------------------------------
# Terraform
# ------------------------------------------------------------

## Terraform init in $(TF_DIR)
tf-init: ## Initialize terraform providers/modules in $(TF_DIR)
	@if [ ! -d "$(TF_DIR)" ]; then echo "Missing directory $(TF_DIR)"; exit 2; fi
	@terraform -chdir=$(TF_DIR) init -upgrade

## Terraform fmt (auto-format)
tf-fmt: ## Format terraform files
	@if [ ! -d "$(TF_DIR)" ]; then echo "Missing directory $(TF_DIR)"; exit 2; fi
	@terraform -chdir=$(TF_DIR) fmt -recursive

## Terraform validate (syntax & basic checks)
tf-validate: ## Validate terraform configuration
	@if [ ! -d "$(TF_DIR)" ]; then echo "Missing directory $(TF_DIR)"; exit 2; fi
	@terraform -chdir=$(TF_DIR) validate

## Terraform plan: make tf-plan VARS="TF_VAR_example=value" or TF_VAR_FILE=terraform.tfvars
tf-plan: ## Create and show an execution plan
	@if [ ! -d "$(TF_DIR)" ]; then echo "Missing directory $(TF_DIR)"; exit 2; fi
	@CMD="terraform -chdir=$(TF_DIR) plan"; \
	if [ -n "$(TF_VAR_FILE)" ]; then CMD="$$CMD -var-file=$(TF_VAR_FILE)"; fi; \
	if [ -n "$(VARS)" ]; then CMD="$(VARS) $$CMD"; fi; \
	echo "[terraform] $$CMD"; \
	eval $$CMD

## Terraform apply: make tf-apply AUTO_APPROVE=yes VARS="TF_VAR_x=y"
tf-apply: ## Apply the planned changes
	@if [ ! -d "$(TF_DIR)" ]; then echo "Missing directory $(TF_DIR)"; exit 2; fi
	@CMD="terraform -chdir=$(TF_DIR) apply"; \
	if [ -n "$(TF_VAR_FILE)" ]; then CMD="$$CMD -var-file=$(TF_VAR_FILE)"; fi; \
	if [ -n "$(AUTO_APPROVE)" ]; then CMD="$$CMD -auto-approve"; fi; \
	if [ -n "$(VARS)" ]; then CMD="$(VARS) $$CMD"; fi; \
	echo "[terraform] $$CMD"; \
	eval $$CMD

## Terraform destroy: make tf-destroy AUTO_APPROVE=yes
tf-destroy: ## Destroy all managed infrastructure in $(TF_DIR)
	@if [ ! -d "$(TF_DIR)" ]; then echo "Missing directory $(TF_DIR)"; exit 2; fi
	@CMD="terraform -chdir=$(TF_DIR) destroy"; \
	if [ -n "$(TF_VAR_FILE)" ]; then CMD="$$CMD -var-file=$(TF_VAR_FILE)"; fi; \
	if [ -n "$(AUTO_APPROVE)" ]; then CMD="$$CMD -auto-approve"; fi; \
	if [ -n "$(VARS)" ]; then CMD="$(VARS) $$CMD"; fi; \
	echo "[terraform] $$CMD"; \
	eval $$CMD

# ------------------------------------------------------------
# Housekeeping
# ------------------------------------------------------------

## Clean caches and build artifacts
clean: ## Remove Python/TF/packer caches and build output
	@echo "[clean] removing Python caches and venv (kept by default)"
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type f -name "*.pyc" -delete
	@echo "[clean] Terraform/packer leftovers"
	@rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl || true
	@rm -rf output/ packer_cache/ || true
