.PHONY: help first-apply apply setup requirements lint install-ansible install-lint install-passlib check-env install-nala install-python ssh-key $(ROLE_TAGS) $(PLAYBOOKS)

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Variables
export PATH := $(HOME)/.local/bin:$(PATH)
PYTHON		  		:= python3
PIP			 				:= pip3
APT				:= sudo apt install -y 
NALA				:= sudo nala install -y 
NALA_UPDATE			:= sudo nala update || sudo nala upgrade -y
ANSIBLE_PLAYBOOK:= ansible-playbook
ANSIBLE_LINT		:= ansible-lint
GALAXY		  		:= ansible-galaxy
PLAYBOOK				:= playbooks/all.yml
BECOME		  		:= --ask-become-pass
AS_ROOT		 			:= --extra-vars "ansible_user=root ansible_port=22"

# Local SSH key settings (override at call time if you like)
# Example: make setup SSH_KEY_PATH="$(HOME)/.ssh/my_id_ed25519"
SSH_KEY_PATH     ?= $(HOME)/.ssh/id_ed25519
SSH_KEY_TYPE     ?= ed25519
SSH_KEY_COMMENT  ?= $(shell whoami)@$(shell hostname)
INVENTORY        ?= production/production

# List of all "role" tags
ROLE_TAGS = docker \
	timezone \
	users \
	ssh \
	hostname \
	firewall \
	fail2ban \
	dotfiles \
	monit \
	cockpit \
	borg \
	maldet \
	lynis

# List all available playbooks (from playbooks directory)
PLAYBOOKS = $(shell find playbooks -name '*.yml' -type f | sed 's|playbooks/||;s|\.yml||')

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
help:
		@echo "Usage:"
		@echo	"  make setup         # install python pip deps, galaxy requirements, ansible-lint"
		@echo "  make requirements  # install ansible-galaxy roles from requirements.yml"
		@echo "  make lint          # run ansible-lint on your playbooks"
		@echo "  make first-apply   # Initial bootstrap (root-only, before any users exist)"
		@echo "  make apply         # run all roles"
		@echo "  make <role>        # run one tagged role"
		@echo "  make <playbook>    # run one tagged category"
		@echo
	@echo "Available playbooks: $(PLAYBOOKS)"
	@echo "Available roles: $(ROLE_TAGS)"

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Environment checks
check-env:
	@command -v $(PYTHON) >/dev/null 2>&1 || { \
	  echo >&2 "Error: $(PYTHON) not found. Please install Python 3."; \
	  exit 1; \
	}
	@command -v $(PIP) >/dev/null 2>&1 || { \
	  echo >&2 "Error: $(PIP) not found. Please install pip for Python 3."; \
	  exit 1; \
	}

check-ansible:
	@command -v $(ANSIBLE_LINT) >/dev/null 2>&1 || { \
	  echo >&2 "Error: $(ANSIBLE_LINT) not found. Run `make install-lint`"; \
	  exit 1; \
	}
	@command -v $(ANSIBLE_PLAYBOOK) >/dev/null 2>&1 || { \
	  echo >&2 "Error: $(ANSIBLE_PLAYBOOK) not found. Run `make install-ansible`"; \
	  exit 1; \
	}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# nala-based installs
install-nala:
	@echo "Ensuring Nala is installed..."
	@if command -v nala >/dev/null 2>&1 && command -v nala >/dev/null 2>&1; then \
		echo "Nala already present."; \
	else \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y nala; \
		fi; \
	fi

install-python:
	@echo "Ensuring Python 3 and pip are installed..."
	@if command -v $(PYTHON) >/dev/null 2>&1 && command -v $(PIP) >/dev/null 2>&1; then \
		echo "Python3 and pip3 already present."; \
	else \
		if command -v nala >/dev/null 2>&1; then \
			$(NALA_UPDATE) && $(NALA) python3 python3-pip; \
		elif command -v nala >/dev/null 2>&1; then \
			sudo apt-get update -y && sudo apt-get install -y python3 python3-pip; \
		elif command -v dnf >/dev/null 2>&1; then \
			sudo dnf install -y python3 python3-pip; \
		elif command -v yum >/dev/null 2>&1; then \
			sudo yum install -y python3 python3-pip; \
		elif command -v apk >/dev/null 2>&1; then \
			sudo apk add --no-cache python3 py3-pip; \
		elif command -v pacman >/dev/null 2>&1; then \
			sudo pacman -Sy --noconfirm python python-pip; \
		else \
			echo >&2 "Unsupported package manager. Please install python3 and pip3 manually."; exit 1; \
		fi; \
	fi

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# ssh setup
ssh-key:
	@# Generate a local SSH keypair if it doesn't exist
	@if [ ! -f "$(SSH_KEY_PATH)" ]; then \
		echo "🔑 No SSH key at $(SSH_KEY_PATH). Generating..."; \
		mkdir -p "$$(dirname "$(SSH_KEY_PATH)")"; \
		ssh-keygen -t $(SSH_KEY_TYPE) -f "$(SSH_KEY_PATH)" -N "" -C "$(SSH_KEY_COMMENT)"; \
		echo "✅ Created: $(SSH_KEY_PATH) and $(SSH_KEY_PATH).pub"; \
	else \
		echo "✅ SSH key exists: $(SSH_KEY_PATH)"; \
	fi

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# pip-based installs
install-ansible: check-env
	@echo "Installing Ansible via pip..."
	$(PIP) install --user --upgrade pip setuptools wheel
	$(PIP) install --user ansible


install-lint: check-env
	@echo "Installing ansible-lint via pip..."
	$(PIP) install --user --upgrade ansible-lint

install-passlib: check-env
	@echo "Installing ansible-lint via pip..."
	$(PIP) install --user --upgrade passlib

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Galaxy roles
requirements: check-env check-ansible
	@echo "Installing Ansible Galaxy roles from requirements.yml..."
	$(GALAXY) install -r requirements.yml

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Combined setup
setup: install-nala install-python ssh-key check-env install-ansible install-lint install-passlib requirements
	@echo "✔️  Environment is ready - Ansible, ansible-lint, and Galaxy roles installed."

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Linting
lint: check-ansible
	@echo "Running ansible-lint..."
	$(ANSIBLE_LINT) playbooks/

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Existing targets

# copy-ssh-key:
# 	$(ANSIBLE_PLAYBOOK) playbooks/ansible-ssh-copy-id.yml $(AS_ROOT) --ask-pass

first-apply first-run:
	$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) $(AS_ROOT)

apply run:
	$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) $(BECOME)

# pattern rule: `make docker` → ansible-playbook ... --tags docker
$(ROLE_TAGS):
	$(ANSIBLE_PLAYBOOK) $(PLAYBOOK) $(BECOME) --tags $@

# This runs a specific playbook.
# E.g. `make monitoring` → ansible-playbook ./playbooks/monitoring.yml
$(PLAYBOOKS):
	$(ANSIBLE_PLAYBOOK) ./playbooks/$(@).yml $(BECOME)
