.PHONY: build

help:
	@echo "Available commands:"
	@echo "  make test      - Run tests"
	@echo "  make package   - Precompile Mojo files"
	@echo "  make upload    - Upload package to Prefix"
	@echo "  make publish   - Publish package to Prefix"
	@echo "  make build     - Build the project"
	@echo "  make doc       - Serve documentation"
	@echo "  make shell     - Open a shell"
	@echo "  make clean     - Clean output"

test:
	pixi run test 

package:
	pixi run mojo precompile src/json/ -o json.mojoc

upload:
	export PREFIX_API_KEY=${PREFIX_API_KEY} & bash scripts/publish.sh

publish:
	export PREFIX_API_KEY=${PREFIX_API_KEY} & bash scripts/publish.sh

build:
	rattler-build build -r src -c https://conda.modular.com/max/ -c https://prefix.dev/mojo-force -c https://repo.prefix.dev/modular-community -c conda-forge --skip-existing=all

doc:
	mkdocs serve

shell:
	pixi shell

clean:
	rm -rf output/
