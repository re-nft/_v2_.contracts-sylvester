IMAGE = "renft/registry"
VERSION ?= $(shell cat pyproject.toml| grep version| awk -F'"' {'print $$2'})

docker:
	docker build -t ${IMAGE}:v$(VERSION) .

shell:
	docker build -t ${IMAGE}:v${VERSION}-shell -f poetry.Dockerfile .
	docker run -it --rm -v $(PWD):/registry ${IMAGE}:v${VERSION}-shell

clean-shell:
	docker rmi ${IMAGE}:v${VERSION}-shell
