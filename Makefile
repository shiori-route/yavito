EMACS ?= emacs
ELISP := $(wildcard yavito*.el)
.PHONY: test compile clean

test:
	$(EMACS) -Q --batch -L . --eval '(setq load-prefer-newer t)' -l test/yavito-test.el -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch -L . --eval '(setq load-prefer-newer t byte-compile-error-on-warn t)' -f batch-byte-compile $(ELISP)

clean:
	rm -f $(ELISP:.el=.elc)
