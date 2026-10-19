;;; yavito-core.el --- Registry, provider resolution and object lookup -*- lexical-binding: t; -*-

;; Author: Jingke
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Registry, provider resolution and object lookup.

;;; Code:
(require 'cl-lib)
(require 'yavito-range)


(autoload 'yavito--linear-object "yavito-linear")
(autoload 'yavito--enclosing-object "yavito-enclosing")
(autoload 'yavito--surround-object "yavito-enclosing")
(autoload 'yavito--delimiter-candidates "yavito-enclosing")
(autoload 'yavito--tag-candidates "yavito-tags")

(defgroup yavito nil "Vim-inspired text objects for Emacs regions." :group 'editing)

(defcustom yavito-object-keys
  '((?w . word) (?W . WORD) (?l . line) (?p . paragraph) (?s . sentence)
    (?\( . parentheses) (?\) . parentheses) (?b . parentheses)
    (?\[ . brackets) (?\] . brackets) (?\{ . braces) (?\} . braces) (?B . braces)
    (?< . angles) (?> . angles) (?\" . double-quote) (?\' . single-quote)
    (?` . backtick) (?t . tag) (?S . surround))
  "Alist mapping input characters to object names or other characters.
First entries win.  Character aliases are resolved recursively.  This
variable can be buffer-local; object names are independent of key choices."
  :type '(alist :key-type character :value-type (choice symbol character))
  :group 'yavito)

(defcustom yavito-object-types
  '((word :kind linear :unit ?w :handler yavito--linear-object)
    (WORD :kind linear :unit ?W :handler yavito--linear-object)
    (line :kind linear :unit ?l :handler yavito--linear-object)
    (paragraph :kind linear :unit ?p :handler yavito--linear-object)
    (sentence :kind linear :unit ?s :handler yavito--linear-object)
    (parentheses :kind enclosing :open ?\( :close ?\)
                 :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (brackets :kind enclosing :open ?\[ :close ?\]
              :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (braces :kind enclosing :open ?\{ :close ?\}
            :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (angles :kind enclosing :open ?< :close ?>
            :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (double-quote :kind enclosing :open ?\" :quote t
                  :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (single-quote :kind enclosing :open ?\' :quote t
                  :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (backtick :kind enclosing :open ?` :quote t
              :handler yavito--enclosing-object :candidates yavito--delimiter-candidates)
    (tag :kind enclosing :handler yavito--enclosing-object :candidates yavito--tag-candidates)
    (surround :kind enclosing :handler yavito--surround-object))
  "Alist mapping object names to semantic definitions.
:kind is `linear' or `enclosing', and controls signed count handling.
:handler is a function of SPEC, COUNT and AROUND returning an object made
with `yavito-object-create'.  SPEC includes :name, the resolved object name.
:candidates is an optional zero-argument function returning enclosing
objects for this provider.  It enables participation in generic surround.
Other properties belong to the handler, not the dispatcher.  First entries
win.  Buffer-local values may override definitions."
  :type '(alist :key-type symbol :value-type plist) :group 'yavito)

(defcustom yavito-object-providers nil
  "Alist of object names and provider overrides.
Each value is a plist overriding :handler and/or :candidates, without
changing keys or object semantics.  Set this buffer-locally for a language
backend.  Automatic major-mode registry merging is not yet implemented."
  :type '(alist :key-type symbol :value-type plist) :group 'yavito)

(defun yavito--spec (object &optional seen)
  "Resolve OBJECT key or name to a provider-enriched definition.
Reject alias cycles tracked in SEEN."
  (when (memq object seen) (user-error "Cyclic object alias: %S" object))
  (if (characterp object)
      (let ((entry (assq object yavito-object-keys)))
        (unless entry (user-error "Unknown object key: %c" object))
        (yavito--spec (cdr entry) (cons object seen)))
    (let ((entry (assq object yavito-object-types)))
      (unless entry (user-error "Unknown object: %S" object))
      (let ((spec (copy-sequence (cdr entry)))
            (provider (copy-sequence (cdr (assq object yavito-object-providers)))))
        (while provider
          (setq spec (plist-put spec (pop provider) (pop provider))))
        (plist-put spec :name object)))))

(defun yavito-object-at-point (object &optional count around)
  "Return OBJECT's structured ranges at point for COUNT and AROUND.
OBJECT is an input character or symbolic name; COUNT defaults to one.
AROUND allows a handler to interpret whitespace as part of the requested
object.  The result always includes :type, :inner and :outer.
Preserve point, mark, narrowing and match data, including on failure."
  (setq count (or count 1))
  (unless (and (integerp count) (/= count 0)) (user-error "Count must be nonzero"))
  (let* ((spec (yavito--spec object)) (kind (plist-get spec :kind))
         (handler (plist-get spec :handler)))
    (unless (memq kind '(linear enclosing)) (user-error "Invalid object kind"))
    (unless (functionp handler) (user-error "Missing object handler"))
    (yavito--validate-object
     (save-match-data
       (save-mark-and-excursion
         (save-restriction
           (funcall handler spec (if (eq kind 'enclosing) (abs count) count) around)))))))

(defun yavito-bounds (object count around)
  "Return OBJECT's inner or AROUND bounds for signed COUNT."
  (let ((result (yavito-object-at-point object count around)))
    (plist-get result (if around :outer :inner))))

(provide 'yavito-core)
;;; yavito-core.el ends here
