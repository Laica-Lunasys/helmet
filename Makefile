install:
	@ln -s $(PWD)/helmet.sh $(PWD)/bin/helmet
	@echo "Please Add -> \`export PATH=\"$(PWD)/bin:\$$PATH\"\`"
	@echo "to your shell profile. (do not forget reload.)"

clean:
	@rm -rf $(PWD)/bin/*
