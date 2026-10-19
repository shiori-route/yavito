;;; yavito-range.el --- Object results and range utilities -*- lexical-binding: t; -*-

;; Author: Jingke
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Object results and range utilities.

;;; Code:


(defun yavito-object-create (type inner outer)
  "Return a TYPE object with INNER and OUTER half-open ranges."
  (list :type type :inner inner :outer outer))

(defun yavito--validate-object (object)
  "Validate OBJECT within the accessible buffer and return it."
  (let ((inner (plist-get object :inner)) (outer (plist-get object :outer)))
    (unless (and (plist-get object :type) (symbolp (plist-get object :type))
                 (consp inner) (consp outer)
                 (integerp (car inner)) (integerp (cdr inner))
                 (integerp (car outer)) (integerp (cdr outer))
                 (<= (point-min) (car outer) (car inner)
                     (cdr inner) (cdr outer) (point-max)))
      (user-error "Invalid text object result")))
  (when (plist-member object :extent)
    (let ((extent (plist-get object :extent))
          (inner (plist-get object :inner)) (outer (plist-get object :outer)))
      (unless (and (consp extent) (integerp (car extent)) (integerp (cdr extent))
                   (<= (car outer) (car extent) (car inner)
                       (cdr inner) (cdr extent) (cdr outer)))
        (user-error "Invalid structural extent"))))
  object)

(defun yavito--extend-whitespace (range chars backward)
  "Extend RANGE over CHARS, preferring BACKWARD and falling back forward."
  (let ((beg (car range)) (end (cdr range)))
    (save-excursion
      (goto-char (if backward beg end))
      (if backward (skip-chars-backward chars) (skip-chars-forward chars))
      (if (/= (point) (if backward beg end))
          (if backward (setq beg (point)) (setq end (point)))
        (goto-char (if backward end beg))
        (if backward (skip-chars-forward chars) (skip-chars-backward chars))
        (if backward (setq end (point)) (setq beg (point)))))
    (cons beg end)))

(provide 'yavito-range)
;;; yavito-range.el ends here
