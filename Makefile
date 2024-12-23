.PHONY: help render local



render: ## render to public folder
	@hugo --theme=hugo-theme-stack --baseURL="http://www.aproton.tech"

local: ## run local server
	@hugo server --theme=hugo-theme-stack --buildDrafts

## make help(begin)
help:
	@echo "Available commands:"
	@grep -E '^[a-zA-Z0-9_]+: +##' $(MAKEFILE_LIST) | sed -E 's/(.+): +## (.+)/  make \1: \2/' 
## make help(end)