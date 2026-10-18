;;; yavito.el --- Select text objects as Emacs regions -*- lexical-binding: t; -*-

;; Author: Jingke
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: editing, convenience
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Bind `yavito-select' to a prefix key.  Type [-][COUNT]iOBJECT
;; or [-][COUNT]aOBJECT.  Objects: w W l p ( ) [ ] { } " ' ` s.
;; This package selects regions; ordinary Emacs commands operate on them.

;;; Code:
(require 'cl-lib)

(defun yavito--escaped-p (pos)
  "Return non-nil when character at POS follows an odd run of backslashes."
  (let ((n 0))
    (save-excursion
      (goto-char pos)
      (while (and (> (point) (point-min)) (eq (char-before) ?\\))
        (cl-incf n) (backward-char)))
    (cl-oddp n)))

(defun yavito--pairs ()
  "Return mechanically matched bracket and same-line quote ranges.
Each entry is (BEGIN END TYPE), with END exclusive.  Brackets in
quoted ranges are ignored.  Mismatched closers reset the bracket stack."
  (save-excursion
    (goto-char (point-min))
    (let (stack pairs quote start)
      (while (< (point) (point-max))
        (let ((c (char-after)) (pos (point)))
          (cond
           ((eq c ?\n) (setq quote nil start nil))
           ((yavito--escaped-p pos) nil)
           (quote
            (when (eq c quote)
              (push (list start (1+ pos) quote) pairs)
              (setq quote nil start nil)))
           ((memq c '(?\" ?\' ?`)) (setq quote c start pos))
           ((memq c '(?\( ?\[ ?\{)) (push (cons c pos) stack))
           ((memq c '(?\) ?\] ?\}))
            (let ((open (car (rassq c '((?\( . ?\)) (?\[ . ?\]) (?\{ . ?\}))))))
              (if (eq (caar stack) open)
                  (push (list (cdr (pop stack)) (1+ pos) open) pairs)
                (setq stack nil))))))
        (forward-char))
      pairs)))

(defun yavito--units (object)
  "Return ordered ranges for linear OBJECT in the accessible buffer."
  (save-excursion
    (goto-char (point-min))
    (let (ranges)
      (pcase object
        ((or ?w ?W)
         (while (re-search-forward
                 (if (eq object ?W) "[^ \t\n\r]+"
                   "[[:word:]_]+\\|[^[:word:]_ \t\n\r]+") nil t)
           (push (cons (match-beginning 0) (match-end 0)) ranges)))
        (?l
         (while (< (point) (point-max))
           (push (cons (line-beginning-position) (line-end-position)) ranges)
           (forward-line 1)))
        (?p
         (while (< (point) (point-max))
           (if (looking-at-p "[ \t]*$") (forward-line 1)
             (let ((beg (point)))
               (while (and (< (point) (point-max))
                           (not (looking-at-p "[ \t]*$")))
                 (forward-line 1))
               (push (cons beg (if (and (> (point) beg)
                                        (eq (char-before) ?\n))
                                   (1- (point)) (point))) ranges))))))
      (nreverse ranges))))

(defun yavito--around (range object backward)
  "Extend RANGE around OBJECT, preferring BACKWARD whitespace when non-nil."
  (let ((beg (car range)) (end (cdr range)))
    (save-excursion
      (cond
       ((eq object ?l)
        (goto-char end)
        (when (eq (char-after) ?\n) (cl-incf end)))
       ((eq object ?p)
        (goto-char end)
        (skip-chars-forward " \t\r\n")
        (if (> (point) end) (setq end (point))
          (goto-char beg) (skip-chars-backward " \t\r\n") (setq beg (point))))
       (t
        (goto-char (if backward beg end))
        (if backward (skip-chars-backward " \t") (skip-chars-forward " \t"))
        (if (/= (point) (if backward beg end))
            (if backward (setq beg (point)) (setq end (point)))
          (goto-char (if backward end beg))
          (if backward (skip-chars-forward " \t") (skip-chars-backward " \t"))
          (if backward (setq end (point)) (setq beg (point))))))
    (cons beg end))))

(defun yavito-bounds (object count around)
  "Return bounds for OBJECT, signed COUNT and AROUND without moving point."
  (unless (and (integerp count) (/= count 0)) (user-error "Count must be nonzero"))
  (let ((pos (point)) (n (abs count)) (backward (< count 0)))
    (if (memq object '(?w ?W ?l ?p))
        (let* ((units (yavito--units object))
               (index (cl-position-if
                       (lambda (r) (and (<= (car r) pos)
                                        (if (memq object '(?l ?p))
                                            (<= pos (cdr r)) (< pos (cdr r))))) units))
               range from-whitespace)
          (when (and (null index) (eobp))
            (setq index (cl-position-if (lambda (r) (= pos (cdr r))) units)))
          (when (and (null index) (memq object '(?w ?W))
                     (memq (char-after) '(?\s ?\t)))
            (setq from-whitespace t)
            (let* ((white (save-excursion
                            (skip-chars-backward " \t")
                            (let ((beg (point)))
                              (skip-chars-forward " \t") (cons beg (point)))))
                   (selected (if around
                                 (cl-remove-if-not
                                  (lambda (r) (if backward (<= (cdr r) (car white))
                                                (>= (car r) (cdr white)))) units)
                               nil)))
              (if around
                  (progn
                    (when backward (setq selected (reverse selected)))
                    (unless (>= (length selected) n) (user-error "Not enough objects"))
                    (setq units (sort (append (cl-subseq selected 0 n) (list white))
                                      (lambda (a b) (< (car a) (car b))))
                          index (if backward n 0) n (1+ n)))
                (setq units (sort (cons white units) (lambda (a b) (< (car a) (car b))))
                      index (cl-position white units :test #'equal)))))
          (unless index (user-error "No object at point"))
          (let ((other (+ index (* (if backward -1 1) (1- n)))))
            (unless (and (>= other 0) (< other (length units)))
              (user-error "Not enough objects"))
            (setq range (cons (car (nth (min index other) units))
                              (cdr (nth (max index other) units)))))
          (when (and (eq object ?l) (not around))
            (setq range (cons (save-excursion
                                (goto-char (car range))
                                (skip-chars-forward " \t" (cdr range)) (point))
                              (cdr range))))
          (if (and around (not from-whitespace))
              (yavito--around range object backward) range))
      (let* ((aliases '((?\) . ?\() (?\] . ?\[) (?\} . ?\{)))
             (type (or (cdr (assq object aliases)) object))
             (pairs (cl-remove-if-not
                     (lambda (r)
                       (and (or (eq type ?s) (eq type (nth 2 r)))
                            (<= (car r) pos) (< pos (cadr r))))
                     (yavito--pairs))))
        (unless (memq type '(?\( ?\[ ?\{ ?\" ?\' ?` ?s))
          (user-error "Unknown object: %c" object))
        (setq pairs (sort pairs (lambda (a b)
                                  (< (- (cadr a) (car a)) (- (cadr b) (car b))))))
        (let ((pair (nth (1- n) pairs)))
          (unless pair (user-error "No enclosing object at level %d" n))
          (let ((range (if around (cons (car pair) (cadr pair))
                         (cons (1+ (car pair)) (1- (cadr pair))))))
            (if (and around (memq (nth 2 pair) '(?\" ?\' ?`)))
                (yavito--around range object nil)
              range)))))))

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
    (list (yavito--read-char "Object: w W l p ( [ { \" ' ` s ")
          (* sign (if (equal digits "") 1 (string-to-number digits))) (eq key ?a))))

;;;###autoload
(defun yavito-select (&optional object count around)
  "Select OBJECT with signed COUNT; AROUND includes its boundaries.
Interactively read [-][COUNT]iOBJECT or [-][COUNT]aOBJECT.
Negative counts reverse linear selections; enclosing objects ignore the sign."
  (interactive (yavito--read))
  (let* ((count (or count 1))
         (linear (memq object '(?w ?W ?l ?p)))
         (range (yavito-bounds object count around))
         (backward (and linear (< count 0))))
    (push-mark (if backward (cdr range) (car range)) t t)
    (goto-char (if backward (car range) (cdr range)))
    (setq deactivate-mark nil)
    (when (and (< count 0) (not linear))
      (message "Warning: enclosing objects ignore direction; used count %d" (abs count)))))

(provide 'yavito)
;;; yavito.el ends here
