;;; yavito-enclosing.el --- Enclosing providers and surround composition -*- lexical-binding: t; -*-

;; Author: Jingke
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Enclosing providers and surround composition.

;;; Code:
(require 'yavito-core)

(defun yavito--delimiter-specs ()
  "Return effective delimiter definitions in registry order."
  (let (seen specs)
    (dolist (entry yavito-object-types)
      (unless (memq (car entry) seen)
        (push (car entry) seen)
        (let ((spec (yavito--spec (car entry))))
          (when (and (plist-get spec :open)
                     (eq (plist-get spec :candidates) #'yavito--delimiter-candidates))
            (push spec specs)))))
    (nreverse specs)))

(defun yavito--delimiter-object (spec beg end)
  "Return the delimiter SPEC object spanning BEG to END."
  (let* ((extent (cons beg end))
         (outer (if (plist-get spec :quote)
                    (yavito--extend-whitespace extent " \t" nil) extent)))
    (append (yavito-object-create (plist-get spec :name)
                                  (cons (1+ beg) (1- end)) outer)
            (list :extent extent))))

(defun yavito--quote-candidates (specs)
  "Return quote objects containing point from SPECS on the current line.
Each quote type pairs independently; one quote cannot hide another type."
  (let ((pos (point)) starts objects (escaped nil))
    (save-excursion
      (beginning-of-line)
      (let ((limit (line-end-position)))
        (while (< (point) limit)
          (let ((c (char-after)))
            (unless escaped
              (dolist (spec specs)
                (when (and (plist-get spec :quote) (eq c (plist-get spec :open)))
                  (let* ((name (plist-get spec :name)) (start (assq name starts)))
                    (if start
                        (progn
                          (when (<= (cdr start) pos (point))
                            (push (yavito--delimiter-object spec (cdr start) (1+ (point))) objects))
                          (setq starts (assq-delete-all name starts)))
                      (push (cons name (point)) starts))))))
            (setq escaped (and (eq c ?\\) (not escaped))))
          (forward-char))))
    (nreverse objects)))

(defun yavito--bracket-candidates (specs)
  "Return bracket objects containing point from SPECS in one forward scan.
Maintain escape parity incrementally.  Use the major mode syntax table
and syntax properties to distinguish code, strings and comments.  Include
literal pairs only in the string containing point, using separate stacks
so they cannot consume code delimiters or pairs in another string.
Quote text objects remain independent character-based pairs."
  (let* ((pos (point))
         (initial-state (save-excursion (syntax-ppss pos)))
         (target-string (and (nth 3 initial-state) (nth 8 initial-state)))
         brackets stacks objects escaped delimiter-chars)
    (dolist (spec specs)
      (when (plist-get spec :close)
        (push spec brackets)
        (cl-pushnew (plist-get spec :open) delimiter-chars)
        (cl-pushnew (plist-get spec :close) delimiter-chars)))
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((c (char-after)))
          (when (and (not escaped) (memq c delimiter-chars))
            (let* ((state (save-excursion (syntax-ppss (point))))
                   (context (and (nth 3 state) (nth 8 state))))
              (when (and (not (nth 4 state))
                         (or (null context) (equal context target-string)))
                ;; Isolate stacks by both delimiter type and string context.
                ;; Unmatched literal pairs cannot consume outer code pairs.
                (dolist (spec brackets)
                  (let ((key (cons context (plist-get spec :name))))
                    (cond
                     ((eq c (plist-get spec :open))
                      (let ((entry (assoc key stacks)))
			(if entry (push (point) (cdr entry))
			  (push (list key (point)) stacks))))
                     ((eq c (plist-get spec :close))
                      (let ((entry (assoc key stacks)))
			(when (cdr entry)
			  (let ((beg (pop (cdr entry))))
                            (when (<= beg pos (point))
                              (push (yavito--delimiter-object spec beg (1+ (point))) objects))))))))))))
          (setq escaped (and (eq c ?\\) (not escaped))))
        (forward-char)))
    (nreverse objects)))

(defun yavito--delimiter-candidates ()
  "Return registered quote and bracket objects containing point."
  (let ((specs (yavito--delimiter-specs)))
    (append (yavito--quote-candidates specs) (yavito--bracket-candidates specs))))

(defun yavito--candidate-extent (object)
  "Return OBJECT's structural extent, excluding optional whitespace."
  (or (plist-get object :extent) (plist-get object :outer)))

(defun yavito--choose-enclosing (objects count)
  "Choose level COUNT from a true containment chain of OBJECTS.
Deduplicate equal extents.  Preserve provider order for equal-sized
candidates and skip crossing ranges that do not contain the prior layer."
  (let ((seen (make-hash-table :test #'equal)) candidates chain previous)
    (dolist (object objects)
      (yavito--validate-object object)
      (let ((range (yavito--candidate-extent object)))
        (when (and (<= (car range) (point)) (< (point) (cdr range))
                   (not (gethash range seen)))
          (puthash range t seen)
          (push object candidates))))
    (setq candidates
          (cl-stable-sort (nreverse candidates)
                          (lambda (a b)
                            (let ((a (yavito--candidate-extent a))
                                  (b (yavito--candidate-extent b)))
                              (< (- (cdr a) (car a)) (- (cdr b) (car b)))))))
    (dolist (object candidates)
      (let ((range (yavito--candidate-extent object)))
        (when (or (null previous)
                  (and (<= (car range) (car previous))
                       (<= (cdr previous) (cdr range))))
          (push object chain) (setq previous range))))
    (or (nth (1- count) (nreverse chain))
        (user-error "No enclosing object at level %d" count))))

(defun yavito--enclosing-object (spec count _around)
  "Find enclosing SPEC at level COUNT."
  (let ((provider (plist-get spec :candidates)) (name (plist-get spec :name)))
    (unless provider (user-error "No enclosing candidates provider"))
    (yavito--choose-enclosing
     (cl-remove-if-not (lambda (object) (eq (plist-get object :type) name))
                       (funcall provider)) count)))

(defun yavito--surround-object (_spec count _around)
  "Compose registered enclosing providers and select level COUNT."
  (let (seen providers objects)
    (dolist (entry yavito-object-types)
      (unless (memq (car entry) seen)
        (push (car entry) seen)
        (let ((provider (plist-get (yavito--spec (car entry)) :candidates)))
          (when provider (cl-pushnew provider providers)))))
    (dolist (provider (nreverse providers))
      (setq objects (append objects (funcall provider))))
    (yavito--choose-enclosing objects count)))

(provide 'yavito-enclosing)
;;; yavito-enclosing.el ends here
