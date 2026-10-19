;;; yavito-tags.el --- HTML and XML tag matching -*- lexical-binding: t; -*-

;; Author: Jingke
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Character-based tag matching for enclosing objects. This module returns
;; whole and interior boundaries without selecting a region.

;;; Code:
(require 'yavito-core)

(defun yavito--tag-pairs ()
  "Return tag ranges as (BEGIN END t INNER-BEGIN INNER-END).
Match names case-insensitively.  Ignore comments, CDATA, processing
instructions, self-closing tags, HTML void tags and stray closing tags."
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search t) stack pairs)
      (while (search-forward "<" nil t)
        (backward-char)
        (cond
         ((looking-at "<!--") (search-forward "-->" nil 'move))
         ((looking-at "<!\\[CDATA\\[") (search-forward "]]>" nil 'move))
         ((looking-at-p (regexp-quote "<?"))
          (search-forward "?>" nil 'move))
         ((looking-at
           "<\\(/?\\)\\([[:alpha:]_][[:alnum:]_.:-]*\\)\\(?:[^<>\"']\\|\"[^\"]*\"\\|'[^']*'\\)*>")
          (let* ((beg (point)) (end (match-end 0))
                 (closing (equal (match-string-no-properties 1) "/"))
                 (name (downcase (match-string-no-properties 2)))
                 (self-closing (eq (char-before (1- end)) ?/)))
            (cond
             (closing
              (let ((entry (assoc name stack)))
                (when entry
                  (push (list (nth 1 entry) end ?t (nth 2 entry) beg) pairs)
                  (setq stack (cdr (member entry stack))))))
             ((or self-closing
                  (member name '("area" "base" "br" "col" "embed" "hr" "img"
                                 "input" "link" "meta" "param" "source" "track" "wbr"))) nil)
             (t (push (list name beg end) stack)))
            (goto-char end)))
         (t (forward-char))))
      pairs)))


(defun yavito--tag-candidates ()
  "Return tag objects with explicit interior and whole ranges."
  (mapcar (lambda (pair)
            (yavito-object-create 'tag (cons (nth 3 pair) (nth 4 pair))
                                  (cons (car pair) (cadr pair))))
          (yavito--tag-pairs)))

(provide 'yavito-tags)
;;; yavito-tags.el ends here
