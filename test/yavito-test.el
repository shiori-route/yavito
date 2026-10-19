;;; yavito-test.el --- Regression tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'yavito)
(defun yavito-test--text (text pos object count around)
  (with-temp-buffer
    (insert text) (goto-char pos)
    (let ((bounds (yavito-bounds object count around)))
      (buffer-substring-no-properties (car bounds) (cdr bounds)))))
(ert-deftest yavito-words ()
  (should (equal (yavito-test--text "one two three four" 6 ?w 2 nil) "two three"))
  (should (equal (yavito-test--text "one two three four" 10 ?w -2 nil) "two three"))
  (should (equal (yavito-test--text "foo-bar baz" 5 ?W 1 nil) "foo-bar"))
  (should (equal (yavito-test--text "one two three" 6 ?w 1 t) "two ")))
(ert-deftest yavito-enclosing ()
  (dolist (c '(?\( ?\)))
    (should (equal (yavito-test--text "(a (bc))" 6 c 2 t) "(a (bc))")))
  (should (equal (yavito-test--text "(a [\"bc\"])" 7 ?S 2 nil) "\"bc\""))
  (should (equal (yavito-test--text "(abc)" 1 ?\) 1 nil) "abc"))
  (should (equal (yavito-test--text "(abc)" 5 ?\( 1 nil) "abc"))
  (should (equal (yavito-test--text "()" 1 ?\( 1 nil) "")))
(ert-deftest yavito-quotes ()
  (should (equal (yavito-test--text "\"a\\\"b\" tail" 4 ?\" 1 nil) "a\\\"b"))
  (should (equal (yavito-test--text "\"abc\" tail" 3 ?\" 1 t) "\"abc\" "))
  (should-error (yavito-test--text "\"a\nb\"" 2 ?\" 1 nil) :type 'user-error))
(ert-deftest yavito-lines-paragraphs ()
  (should (equal (yavito-test--text "  aa\n  bb\ncc\n" 9 ?l -2 nil) "aa\n  bb"))
  (should (equal (yavito-test--text "aa\nbb\n" 2 ?l 1 t) "aa\n"))
  (should (equal (yavito-test--text "aa\n\nbb\n\ncc" 6 ?p -2 nil) "aa\n\nbb")))
(ert-deftest yavito-state ()
  (with-temp-buffer
    (insert "one two") (goto-char 6) (push-mark 2 t t)
    (let ((old (list (point) (mark) mark-active)))
      (should-error (yavito-select ?\( 1 nil) :type 'user-error)
      (should (equal old (list (point) (mark) mark-active))))
    (yavito-select ?w -2 nil)
    (should (= (point) 1)) (should (= (mark) 8))
    (should mark-active)))
(ert-deftest yavito-read ()
  (let ((unread-command-events (string-to-list "-2i(")))
    (should (equal (yavito--read) '(40 -2 nil)))))
(ert-deftest yavito-negative-enclosing ()
  (with-temp-buffer
    (insert "(abc)") (goto-char 3)
    (yavito-select ?\( -1 nil)
    (should (= (point) 5)) (should (= (mark) 2))))
(ert-deftest yavito-whitespace ()
  (should (equal (yavito-test--text "one   two three" 5 ?w 1 nil) "   "))
  (should (equal (yavito-test--text "one   two three" 5 ?w 1 t) "   two"))
  (should (equal (yavito-test--text "one   two three" 5 ?w -1 t) "one   ")))
(ert-deftest yavito-invalid ()
  (should-error (yavito-test--text "abc" 2 ?w 0 nil) :type 'user-error)
  (should-error (yavito-test--text "abc" 2 ?w 2 nil) :type 'user-error)
  (should-error (yavito-test--text "abc (def)" 2 ?\( 1 nil) :type 'user-error)
  (should-error (yavito-test--text "abc" 2 ?z 1 nil) :type 'user-error))
(ert-deftest yavito-cancel ()
  (with-temp-buffer
    (insert "abc") (goto-char 2) (push-mark 1 t t)
    (let ((old (list (point) (mark) mark-active mark-ring))
          (unread-command-events (list ?\C-g)))
      (should (eq (condition-case nil (call-interactively #'yavito-select)
                    (quit 'cancelled)) 'cancelled))
      (should (equal old (list (point) (mark) mark-active mark-ring))))))

(ert-deftest yavito-sentences ()
  (let ((text "First sentence. Second sentence! Third?"))
    (should (equal (yavito-test--text text 8 ?s 1 nil) "First sentence."))
    (should (equal (yavito-test--text text 21 ?s 1 t) "Second sentence! "))
    (should (equal (yavito-test--text text 21 ?s -2 nil)
                   "First sentence. Second sentence!"))
    (should (equal (yavito-test--text text 21 ?s 2 nil)
                   "Second sentence! Third?")))
  (should (equal (yavito-test--text "A.) Next." 2 ?s 1 nil) "A.)"))
  (should (equal (yavito-test--text "Dr.X ends here.\nNext line." 5 ?s 1 nil)
                 "Dr.X ends here."))
  (should (equal (yavito-test--text "No stop\n\nNew paragraph" 3 ?s 1 nil) "No stop")))

(ert-deftest yavito-bracket-aliases ()
  (dolist (object '(?b ?\( ?\)))
    (should (equal (yavito-test--text "(abc)" 3 object 1 nil) "abc")))
  (dolist (object '(?B ?\{ ?\}))
    (should (equal (yavito-test--text "{abc}" 3 object 1 t) "{abc}")))
  (dolist (object '(?< ?>))
    (should (equal (yavito-test--text "<a<b>>" 4 object 2 nil) "a<b>")))
  (should (equal (yavito-test--text "(a < b)" 3 ?b 1 nil) "a < b")))

(ert-deftest yavito-tags ()
  (let ((text "<div class=\"note\">hello <b>world</b></div>"))
    (should (equal (yavito-test--text text 29 ?t 1 nil) "world"))
    (should (equal (yavito-test--text text 29 ?t 1 t) "<b>world</b>"))
    (should (equal (yavito-test--text text 29 ?t 2 nil) "hello <b>world</b>"))
    (should (equal (yavito-test--text text 1 ?t 1 t) text)))
  (should (equal (yavito-test--text "<X a=\"1 > 0\">text</x>" 16 ?t 1 nil) "text"))
  (should (equal (yavito-test--text "<x></x>" 2 ?t 1 nil) ""))
  (should (equal (yavito-test--text "<x>a<br>b<z/>c</x>" 5 ?t 1 nil)
                 "a<br>b<z/>c"))
  (should (equal (yavito-test--text "<x><!-- <fake> -->ok</x>" 20 ?t 1 nil)
                 "<!-- <fake> -->ok"))
  (should (equal (yavito-test--text "<x><![CDATA[<fake>]]>ok</x>" 22 ?t 1 nil)
                 "<![CDATA[<fake>]]>ok"))
  (should-error (yavito-test--text "outside <x>text</x>" 2 ?t 1 nil) :type 'user-error)
  (should-error (yavito-test--text "<br>" 2 ?t 1 nil) :type 'user-error))

(ert-deftest yavito-surround-uppercase ()
  (should (equal (yavito-test--text "<x>(abc)</x>" 6 ?S 1 t) "(abc)"))
  (should (equal (yavito-test--text "<x>(abc)</x>" 6 ?S 2 t) "<x>(abc)</x>"))
  (with-temp-buffer
    (insert "First. Second.") (goto-char 10)
    (yavito-select ?s -2 nil)
    (should (= (point) 1))
    (should (= (mark) (point-max)))))


(ert-deftest yavito-object-registry ()
  (let ((yavito-object-keys (cons '(?x . ?b) yavito-object-keys)))
    (should (equal (yavito-test--text "(abc)" 3 ?x 1 nil) "abc")))
  (let ((yavito-object-keys '((?x . ?y) (?y . ?x))))
    (should-error (yavito-test--text "abc" 2 ?x 1 nil) :type 'user-error))
  (let ((yavito-object-keys (cons '(?| . pipe) yavito-object-keys))
        (yavito-object-types
         (cons '(pipe :kind enclosing :open ?| :quote t
                      :handler yavito--enclosing-object
                      :candidates yavito--delimiter-candidates) yavito-object-types)))
    (should (equal (yavito-test--text "|abc|" 3 ?| 1 nil) "abc")))
  (let ((yavito-object-keys (cons '(?x . guillemets) yavito-object-keys))
        (yavito-object-types
         (cons '(guillemets :kind enclosing :open ?« :close ?»
                            :handler yavito--enclosing-object
                            :candidates yavito--delimiter-candidates) yavito-object-types)))
    (should (equal (yavito-test--text "«abc»" 3 ?x 1 nil) "abc"))))

(ert-deftest yavito-custom-bounds-preserve-state ()
  (with-temp-buffer
    (insert "0123456789") (narrow-to-region 2 8)
    (goto-char 4) (push-mark 3 t t)
    (let* ((before (list (point) (mark) mark-active (point-min) (point-max)))
           (yavito-object-types
            (list (list 'custom :kind 'linear
                        :handler (lambda (_spec _count _around)
                                   (goto-char 6) (set-mark 5) (narrow-to-region 3 7)
                                   (yavito-object-create 'custom '(3 . 7) '(3 . 7)))))))
      (should (equal (yavito-bounds 'custom 1 nil) '(3 . 7)))
      (should (equal before (list (point) (mark) mark-active (point-min) (point-max)))))
    (let ((yavito-object-types
           (list (list 'custom :kind 'linear
                       :handler (lambda (_spec _count _around)
                                  (yavito-object-create 'custom '(1 . 10) '(1 . 10)))))))
      (should-error (yavito-bounds 'custom 1 nil) :type 'user-error))))

(ert-deftest yavito-provider-overrides ()
  (let ((yavito-object-keys '((?x . word)))
        (yavito-object-providers
         (list (list 'word :handler
                     (lambda (spec count _around)
                       (should (= count -2))
                       (yavito-object-create (plist-get spec :name) '(2 . 4) '(1 . 5)))))))
    (should (equal (yavito-test--text "abcdef" 3 ?x -2 nil) "bc"))
    (should (equal (yavito-test--text "abcdef" 3 ?x -2 t) "abcd"))))

(ert-deftest yavito-structured-object ()
  (with-temp-buffer
    (insert "<x>abc</x>") (goto-char 5)
    (let ((object (yavito-object-at-point 'tag)))
      (should (eq (plist-get object :type) 'tag))
      (should (equal (plist-get object :inner) '(4 . 7)))
      (should (equal (plist-get object :outer) '(1 . 11))))))

(ert-deftest yavito-surround-provider-extension ()
  (let* ((calls 0)
         (provider (lambda () (cl-incf calls)
                     (list (yavito-object-create 'environment '(3 . 6) '(1 . 8))))))
    (let ((yavito-object-types
           (append (list (list 'environment :kind 'enclosing
                               :handler #'yavito--enclosing-object :candidates provider)
                         (list 'environment-alias :kind 'enclosing :candidates provider))
                   yavito-object-types)))
      (should (equal (yavito-test--text "xxabcxx" 4 ?S 1 nil) "abc"))
      (should (= calls 1)))))

(ert-deftest yavito-crossing-surrounds ()
  (should (equal (yavito-test--text "(a < b) c >" 6 ?S 1 nil) "a < b"))
  (should-error (yavito-test--text "(a < b) c >" 6 ?S 2 nil) :type 'user-error)
  ;; Crossing candidates must not prevent a genuine outer layer.
  (should (equal (yavito-test--text "{(a < b) c >}" 7 ?S 2 t) "{(a < b) c >}")))

(ert-deftest yavito-independent-quote-types ()
  (should (equal (yavito-test--text "'foo \"bar\" baz'" 8 ?\" 1 nil) "bar"))
  (should (equal (yavito-test--text "\"foo 'bar' baz\"" 8 ?\' 1 nil) "bar"))
  (should (equal (yavito-test--text "'foo \"bar\" baz'" 8 ?S 2 t)
                 "'foo \"bar\" baz'"))
  (should (equal (yavito-test--text "\"(abc)\"" 4 ?S 1 t) "(abc)")))

(ert-deftest yavito-empty-lines ()
  (should (equal (yavito-test--text "" 1 ?l 1 nil) ""))
  (should (equal (yavito-test--text "abc\n" 5 ?l 1 nil) ""))
  (should (equal (yavito-test--text "abc\n" 5 ?l -2 t) "abc\n"))
  (should (equal (yavito-test--text "\n" 1 ?l 1 t) "\n"))
  (should-error (yavito-test--text "abc\n" 5 ?l 2 nil) :type 'user-error))

(ert-deftest yavito-deduplicate-surround-extents ()
  (let* ((provider (lambda ()
                     (list (yavito-object-create 'environment '(3 . 6) '(1 . 8))
                           (yavito-object-create 'other '(3 . 6) '(1 . 8)))))
         (yavito-object-types
          (cons (list 'environment :kind 'enclosing
                      :handler #'yavito--enclosing-object :candidates provider)
                yavito-object-types)))
    (should (equal (yavito-test--text "xxabcxx" 4 ?S 1 nil) "abc"))
    (should-error (yavito-test--text "xxabcxx" 4 ?S 2 nil) :type 'user-error)))

(ert-deftest yavito-invalid-object-results ()
  (dolist (result '((:type broken :inner (1 . 5) :outer (2 . 4))
                    (:type broken :inner (2 . 4) :outer (1 . 5) :extent (3 . 4))))
    (let ((yavito-object-types
           (list (list 'broken :kind 'enclosing
                       :handler (lambda (_spec _count _around) result)))))
      (should-error (yavito-test--text "abcdef" 3 'broken 1 nil) :type 'user-error))))

(ert-deftest yavito-local-linear-traversal ()
  (with-temp-buffer
    (dotimes (_ 10000) (insert "word next\n"))
    (goto-char 3)
    (let ((original (symbol-function 'yavito--linear-unit-at)) (calls 0))
      (cl-letf (((symbol-function 'yavito--linear-unit-at)
                 (lambda (unit) (cl-incf calls) (funcall original unit))))
        (should (equal (yavito-bounds ?w 2 nil) '(1 . 10))))
      (should (= calls 2)))))

(ert-deftest yavito-escape-parity ()
  (dolist (n '(0 1 2 3 1000))
    (let ((text (concat "(" (make-string n ?\\) ")")))
      (if (cl-evenp n)
          (should (equal (yavito-test--text text 1 ?b 1 t) text))
        (should-error (yavito-test--text text 1 ?b 1 t) :type 'user-error)))))

(ert-deftest yavito-word-traversal-reference ()
  ;; Compare local traversal with a simple regex-based reference, including
  ;; adjacent punctuation and mixed Unicode text in both directions.
  (with-temp-buffer
    (insert "alpha beta-gamma, 123 中文\nnext.foo\tlast")
    (dolist (unit '(?w ?W))
      (let (tokens)
        (goto-char (point-min))
        (while (re-search-forward
                (if (eq unit ?W) "[^ \t\r\n]+"
                  "[[:word:]_]+\\|[^[:word:]_ \t\r\n]+") nil t)
          (push (cons (match-beginning 0) (match-end 0)) tokens))
        (setq tokens (nreverse tokens))
        (cl-loop for token in tokens for index from 0 do
                 (dolist (count '(-3 -2 -1 1 2 3))
                   (goto-char (/ (+ (car token) (cdr token)) 2))
                   (let ((other (+ index (* (if (< count 0) -1 1) (1- (abs count))))))
                     (if (and (>= other 0) (< other (length tokens)))
                         (should (equal (yavito-bounds unit count nil)
                                        (cons (car (nth (min index other) tokens))
                                              (cdr (nth (max index other) tokens)))))
                       (should-error (yavito-bounds unit count nil) :type 'user-error)))))))))

(ert-deftest yavito-local-traversal-narrowing ()
  (with-temp-buffer
    (insert "prefix word next suffix")
    (narrow-to-region 8 17)
    (goto-char 10)
    (should (equal (yavito-bounds ?w 2 nil) '(8 . 17)))
    (should-error (yavito-bounds ?w 3 nil) :type 'user-error)
    (should (equal (cons (point-min) (point-max)) '(8 . 17)))
    (should (= (point) 10))))

(ert-deftest yavito-lisp-bracket-syntax ()
  (dolist (text '("(foo 'bar (baz))"
                  "(foo ; a ) in a comment\n bar)"
                  "(foo \"multi\nline (text)\" bar)"
                  "(foo ?\\( bar)"))
    (with-temp-buffer
      (emacs-lisp-mode) (insert text) (goto-char 3)
      (should (equal (yavito-bounds ?\( 1 t)
                     (cons (point-min) (point-max)))))))

(ert-deftest yavito-brackets-ignore-comment-pairs ()
  (dolist (text '("(foo ; (hidden)\n bar)"))
    (with-temp-buffer
      (emacs-lisp-mode) (insert text)
      (goto-char (point-min)) (search-forward "hidden")
      (should (equal (yavito-bounds ?\( 1 t) (cons (point-min) (point-max))))
      (should-error (yavito-bounds ?\( 2 t) :type 'user-error))))

(ert-deftest yavito-brackets-use-syntax-properties ()
  (with-temp-buffer
    (insert "(x ! ) ! y)")
    ;; Model a mode with ! as a syntax-propertized string delimiter.
    (put-text-property 4 5 'syntax-table (string-to-syntax "\""))
    (put-text-property 8 9 'syntax-table (string-to-syntax "\""))
    (setq-local parse-sexp-lookup-properties t)
    (goto-char 3)
    (should (equal (yavito-bounds ?\( 1 t) '(1 . 12)))))

(ert-deftest yavito-string-local-bracket-layers ()
  (with-temp-buffer
    (emacs-lisp-mode) (insert "(foo \"hello (world)\")")
    (goto-char (point-min)) (search-forward "world")
    (let ((whole (buffer-string)))
      (let ((range (yavito-bounds ?b 1 nil)))
        (should (equal (buffer-substring-no-properties (car range) (cdr range)) "world")))
      (let ((range (yavito-bounds ?b 1 t)))
        (should (equal (buffer-substring-no-properties (car range) (cdr range)) "(world)")))
      (let ((range (yavito-bounds ?b 2 t)))
        (should (equal (buffer-substring-no-properties (car range) (cdr range)) whole)))
      (should-error (yavito-bounds ?b 3 t) :type 'user-error)
      ;; From code, literal pairs must not count as extra layers.
      (goto-char 3)
      (should (equal (yavito-bounds ?b 1 t) (cons (point-min) (point-max)))))))

(ert-deftest yavito-string-bracket-context-isolation ()
  (dolist (text '("(foo \"hello world\")"
                  "(foo \"hello (world\")"
                  "(foo \"hello )world\")"
                  "(foo \"left (\" \"right )world\")"))
    (with-temp-buffer
      (emacs-lisp-mode) (insert text)
      (goto-char (point-min)) (search-forward "world")
      (should (equal (yavito-bounds ?b 1 t) (cons (point-min) (point-max))))
      (should-error (yavito-bounds ?b 2 t) :type 'user-error))))

(ert-deftest yavito-string-brackets-multiline-and-surround ()
  (with-temp-buffer
    (emacs-lisp-mode) (insert "(foo \"hello (\n[world])\")")
    (goto-char (point-min)) (search-forward "world")
    (let ((range (yavito-bounds ?S 1 nil)))
      (should (equal (buffer-substring-no-properties (car range) (cdr range)) "world")))
    (let ((range (yavito-bounds ?b 1 nil)))
      (should (equal (buffer-substring-no-properties (car range) (cdr range)) "\n[world]")))
    (should (equal (yavito-bounds ?b 2 t) (cons (point-min) (point-max))))))
