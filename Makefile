.PHONY: help fmt init ecr-bootstrap images apply destroy local local-down

help:
	@echo "Targets:"
	@echo "  make local           Run UI + catalog + sales locally"
	@echo "  make local-down      Stop the local stack"
	@echo "  make init            terraform init"
	@echo "  make ecr-bootstrap   Create ECR repos"
	@echo "  make images          Build and push images"
	@echo "  make apply           terraform apply"
	@echo "  make destroy         terraform destroy (includes Private CA)"

fmt:
	terraform -chdir=terraform fmt -recursive

init:
	terraform -chdir=terraform init

ecr-bootstrap:
	terraform -chdir=terraform apply -target=module.ecr -auto-approve

images:
	chmod +x scripts/build-and-push.sh
	./scripts/build-and-push.sh

apply:
	terraform -chdir=terraform apply

destroy:
	terraform -chdir=terraform destroy

local:
	docker compose up --build

local-down:
	docker compose down -v
