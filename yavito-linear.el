;;; yavito-linear.el --- Linear objects and counted range selection -*- lexical-binding: t; -*-

;; Author: Jingke
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Linear objects and counted range selection.

;;; Code:
(require 'yavito-core)

(defun yavito--word-class (unit char)
  "Return the token class of CHAR for UNIT, or nil for non-token whitespace."
  (cond ((null char) nil)
        ((memq char '(?\s ?\t)) 'space)
        ((memq char '(?\n ?\r)) nil)
        ((eq unit ?W) 'WORD)
        ((string-match-p "[[:word:]_]" (char-to-string char)) 'word)
        (t 'punctuation)))

(defun yavito--word-at (unit)
  "Return the word or horizontal whitespace range at point for UNIT."
  (when (and (eobp) (> (point) (point-min))) (backward-char))
  (let* ((class (yavito--word-class unit (char-after)))
         (chars (pcase class
                  ('space " \t") ('WORD "^ \t\r\n")
                  ('word "[:word:]_") ('punctuation "^[:word:]_ \t\r\n"))))
    (when chars
      (skip-chars-backward chars)
      (let ((beg (point)))
        (skip-chars-forward chars) (cons beg (point))))))

(defun yavito--paragraph-at ()
  "Return the nonblank paragraph at point, or nil on a blank line."
  (unless (save-excursion (beginning-of-line) (looking-at-p "[ \t]*$"))
    (beginning-of-line)
    (while (and (> (point) (point-min))
                (save-excursion (forward-line -1) (not (looking-at-p "[ \t]*$"))))
      (forward-line -1))
    (let ((beg (point)))
      (while (and (< (point) (point-max)) (not (looking-at-p "[ \t]*$")))
        (forward-line 1))
      (cons beg (if (and (> (point) beg) (eq (char-before) ?\n))
                    (1- (point)) (point))))))

(defun yavito--sentence-at ()
  "Return the sentence at point, scanning only its paragraph."
  (let* ((pos (point)) (paragraph (save-excursion (yavito--paragraph-at))) found)
    (when paragraph
      (goto-char (car paragraph))
      (let ((limit (cdr paragraph)))
        (while (and (not found) (< (point) limit) (<= (point) pos))
          (skip-chars-forward " \t\r\n" limit)
          (when (< (point) limit)
            (let ((beg (point)) end)
              (while (and (not end) (re-search-forward "[.!?]" limit t))
                (while (and (< (point) limit)
                            (memq (char-after) '(?\) ?\] ?\" ?\')))
                  (forward-char))
                (when (or (= (point) limit) (memq (char-after) '(?\s ?\t ?\n ?\r)))
                  (setq end (point))))
              (goto-char (or end limit))
              (when (and (<= beg pos)
                         (or (< pos (point)) (and (= pos (point)) (= pos (point-max)))))
                (setq found (cons beg (point)))))))))
    found))

(defun yavito--linear-unit-at (unit)
  "Return the UNIT range at point, without changing point."
  (save-excursion
    (pcase unit
      ((or ?w ?W) (yavito--word-at unit))
      (?l (cons (line-beginning-position) (line-end-position)))
      (?p (yavito--paragraph-at))
      (?s (yavito--sentence-at))
      (_ (user-error "Unknown linear unit: %S" unit)))))

(defun yavito--linear-neighbor (unit range backward)
  "Return the neighboring UNIT of RANGE in BACKWARD direction, or nil."
  (save-excursion
    (if (eq unit ?l)
        (progn
          (goto-char (car range))
          (when (= (forward-line (if backward -1 1)) 0)
            (yavito--linear-unit-at unit)))
      (goto-char (if backward (car range) (cdr range)))
      (if backward (skip-chars-backward " \t\r\n") (skip-chars-forward " \t\r\n"))
      (when (if backward (> (point) (point-min)) (< (point) (point-max)))
        (when backward (backward-char))
        (yavito--linear-unit-at unit)))))

(defun yavito--linear-object (spec count around)
  "Return SPEC for COUNT and AROUND, visiting only the necessary units."
  (let* ((unit (plist-get spec :unit)) (backward (< count 0))
         (first (yavito--linear-unit-at unit))
         (white (and (memq unit '(?w ?W))
                     (memq (char-after) '(?\s ?\t))))
         (steps (+ (1- (abs count)) (if (and white around) 1 0)))
         (last first))
    (unless first (user-error "No object at point"))
    (dotimes (_ steps)
      (setq last (yavito--linear-neighbor unit last backward))
      (unless last (user-error "Not enough objects")))
    (let* ((whole (cons (min (car first) (car last)) (max (cdr first) (cdr last))))
           (inner whole)
           (outer (cond
                   ((eq unit ?l)
                    (cons (car whole)
                          (save-excursion (goto-char (cdr whole))
                                          (if (eq (char-after) ?\n) (1+ (point)) (point)))))
                   (white whole)
                   (t (yavito--extend-whitespace
                       whole (if (memq unit '(?p ?s)) " \t\r\n" " \t") backward)))))
      (when (eq unit ?l)
        (setq inner (cons (save-excursion
                            (goto-char (car whole))
                            (skip-chars-forward " \t" (cdr whole)) (point))
                          (cdr whole))))
      (yavito-object-create (plist-get spec :name) inner outer))))

(provide 'yavito-linear)
;;; yavito-linear.el ends here
