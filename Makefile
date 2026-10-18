EMACS ?= emacs
.PHONY: test compile

test:
	$(EMACS) -Q --batch -L . -l test/yavito-test.el -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile yavito.el
