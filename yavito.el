;;; yavito.el --- Select text objects as Emacs regions -*- lexical-binding: t; -*-

;; Author: Jingke
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: editing, convenience
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Bind `yavito-select' to a prefix key. Type [-][COUNT]iOBJECT
;; or [-][COUNT]aOBJECT. Objects are configured in `yavito-object-keys'.
;; This entry point reads keys and activates ordinary Emacs regions; the core
;; and object modules compute the bounds.

;;; Code:
(require 'yavito-core)

(defun yavito--read-char (prompt)
  "Read one character with PROMPT, honoring keyboard quit."
  (let ((key (read-char prompt)))
    (when (eq key ?\C-g) (signal 'quit nil))
    key))

(defun yavito--read ()
  "Read and return (OBJECT COUNT AROUND)."
  (let ((key (yavito--read-char "Object: [-][count] i/a object "))
        (sign 1) (digits ""))
    (when (eq key ?-) (setq sign -1 key (yavito--read-char "Count or i/a: ")))
    (while (and (>= key ?0) (<= key ?9))
      (setq digits (concat digits (string key)) key (yavito--read-char "Count or i/a: ")))
    (unless (memq key '(?i ?a)) (user-error "Expected i or a"))
    (list (yavito--read-char
           (format "Object (%s): "
                   (mapconcat (lambda (entry) (char-to-string (car entry)))
                              yavito-object-keys " ")))
          (* sign (if (equal digits "") 1 (string-to-number digits))) (eq key ?a))))

;;;###autoload
(defun yavito-select (&optional object count around)
  "Select OBJECT with signed COUNT; AROUND includes its boundaries.
Interactively read [-][COUNT]iOBJECT or [-][COUNT]aOBJECT.
Negative counts reverse linear selections; enclosing objects ignore the sign."
  (interactive (yavito--read))
  (let* ((count (or count 1))
         (linear (eq (plist-get (yavito--spec object) :kind) 'linear))
         (range (yavito-bounds object count around))
         (backward (and linear (< count 0))))
    (push-mark (if backward (cdr range) (car range)) t t)
    (goto-char (if backward (car range) (cdr range)))
    (setq deactivate-mark nil)
    (when (and (< count 0) (not linear))
      (message "Warning: enclosing objects ignore direction; used count %d" (abs count)))))

(provide 'yavito)
;;; yavito.el ends here
