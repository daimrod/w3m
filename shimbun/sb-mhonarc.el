;;; sb-mhonarc.el --- shimbun backend class for mhonarc

;; Copyright (C) 2001 Yuuichi Teranishi <teranisi@gohome.org>
;; Copyright (C) 2001 Akihiro Arisawa   <ari@mbf.sphere.ne.jp>

;; Author: TSUCHIYA Masatoshi <tsuchiya@namazu.org>,
;;         Akihiro Arisawa    <ari@mbf.sphere.ne.jp>,
;;         Yuuichi Teranishi  <teranisi@gohome.org>
;; Keywords: news

;; This file is a part of shimbun.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's maintainer or write to: The Free Software Foundation,
;; Inc.; 59 Temple Place, Suite 330; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Original code was nnshimbun.el written by
;; TSUCHIYA Masatoshi <tsuchiya@namazu.org>.

;;; Code:

(require 'shimbun)

(eval-and-compile
  (luna-define-class shimbun-mhonarc (shimbun)
		     (reverse-flag litemplate-regexp))
  (luna-define-internal-accessors 'shimbun-mhonarc))

(defvar shimbun-mhonarc-litemplate-regexp
  "<strong><a name=\"\\([0-9]+\\)\" href=\"\\(msg[0-9]+.html\\)\">\\([^<]+\\)</a></strong>\n<ul><li><em>From</em>: \\([^<]+\\)</li></ul>")

(luna-define-method initialize-instance :after ((shimbun shimbun-mhonarc)
						&rest init-args)
  (shimbun-mhonarc-set-reverse-flag-internal
   shimbun
   (symbol-value
    (intern-soft (concat "shimbun-" (shimbun-server-internal shimbun)
			 "-reverse-flag"))))
  (shimbun-mhonarc-set-litemplate-regexp-internal
   shimbun
   (symbol-value
    (intern-soft (concat "shimbun-" (shimbun-server-internal shimbun)
			 "-litemplate-regexp"))))
  shimbun)

(defun shimbun-mhonarc-replace-newline-to-space (string)
  (let ((i (length string)))
    (while (> i 0)
      (setq i (1- i))
      (when (eq (aref string i) ?\n)
	(aset string i ? )))
    string))

(defmacro shimbun-mhonarc-extract-header-values (shimbun url headers aux)
  (` (let ((id (format "<%s%s%%%s>"
		       (or (, aux) "")
		       (match-string 1)
		       (shimbun-current-group-internal (, shimbun))))
	   (url (shimbun-expand-url (match-string 2) (, url)))
	   (subject (shimbun-mhonarc-replace-newline-to-space (match-string 3)))
	   (from (shimbun-mhonarc-replace-newline-to-space (match-string 4))))
       (if (shimbun-search-id (, shimbun) id)
	   (throw 'stop (, headers))
	 (push (shimbun-make-header 0
				    (shimbun-mime-encode-string subject)
				    (shimbun-mime-encode-string from)
				    "" id "" 0 0 url)
	       (, headers))))))

(defmacro shimbun-mhonarc-get-headers (shimbun url headers &optional aux)
  (` (let ((case-fold-search t)
	 (regexp (or (shimbun-mhonarc-litemplate-regexp-internal (, shimbun))
		     shimbun-mhonarc-litemplate-regexp)))
     (if (shimbun-mhonarc-reverse-flag-internal (, shimbun))
	 (progn
	   (goto-char (point-min))
	   (while (re-search-forward regexp nil t)
	     (shimbun-mhonarc-extract-header-values (, shimbun) (, url)
						    (, headers) (, aux))
	     (forward-line 1)))
       (goto-char (point-max))
       (while (re-search-backward regexp nil t)
	 (shimbun-mhonarc-extract-header-values (, shimbun) (, url)
						(, headers) (, aux))
	 (forward-line 0)))
     (, headers))))

(luna-define-method shimbun-get-headers ((shimbun shimbun-mhonarc)
					 &optional range)
  (let (headers)
    (catch 'stop
      (shimbun-mhonarc-get-headers shimbun (shimbun-index-url shimbun)
				   headers))))

(defvar shimbun-mhonarc-optional-headers
  '("x-ml-count" "x-mail-count" "x-ml-name" "user-agent"))

(luna-define-method shimbun-make-contents ((shimbun shimbun-mhonarc)
					   header)
  (if (search-forward "<!--X-Head-End-->" nil t)
      (progn
	(forward-line 0)
	;; Processing headers.
	(save-restriction
	  (narrow-to-region (point-min) (point))
	  (shimbun-decode-entities)
	  (goto-char (point-min))
	  (while (search-forward "\n<!--X-" nil t)
	    (replace-match "\n"))
	  (goto-char (point-min))
	  (while (search-forward " -->\n" nil t)
	    (replace-match "\n"))
	  (goto-char (point-min))
	  (while (search-forward "\t" nil t)
	    (replace-match " "))
	  (goto-char (point-min))
	  (let (buf refs reply-to)
	    (while (not (eobp))
	      (cond
	       ((looking-at "<!--")
		(delete-region (point) (progn (forward-line 1) (point))))
	       ((looking-at "Subject: +")
		(shimbun-header-set-subject header
					    (shimbun-mime-encode-string
					     (shimbun-header-field-value)))
		(delete-region (point) (progn (forward-line 1) (point))))
	       ((looking-at "From: +")
		(shimbun-header-set-from header
					 (shimbun-mime-encode-string
					  (shimbun-header-field-value)))
		(delete-region (point) (progn (forward-line 1) (point))))
	       ((looking-at "Date: +")
		(let ((date (shimbun-header-field-value)))
		  (shimbun-header-set-date
		   header
		   (if (string-match "\\([-+][0-9][0-9][0-9][0-9]\\) +([a-Z][a-Z][a-Z])\\'"
				     date)
		       (substring date 0 (match-end 1))
		     date)))
		(delete-region (point) (progn (forward-line 1) (point))))
	       ((looking-at "Message-Id: +")
		(shimbun-header-set-id header
		 (concat "<" (shimbun-header-field-value) ">"))
		(delete-region (point) (progn (forward-line 1) (point))))
	       ((looking-at "Reference: +")
		(push (concat "<" (shimbun-header-field-value) ">") refs)
		(delete-region (point) (progn (forward-line 1) (point))))
	       ((looking-at "Content-Type: ")
		(delete-region (point) (progn (forward-line 1) (point))))
	       (t (forward-line 1))))
	    (if (setq reply-to (shimbun-reply-to shimbun))
		(insert "Reply-To: " reply-to "\n"))
	    (insert "MIME-Version: 1.0\n")
	    (insert "Content-Type: text/html; charset=ISO-2022-JP\n")
	    (if refs
		(shimbun-header-set-references header
					       (mapconcat 'identity
							  (reverse refs) " ")))
	    (insert "\n")
	    (goto-char (point-min))
	    (shimbun-header-insert shimbun header))
	  (goto-char (point-max)))
	;; Processing optional headers.
	(let ((alist)
	      (cur-point (point))
	      (start (search-forward "<!--X-Head-of-Message-->" nil t))
	      (end (and (search-forward "<!--X-Head-of-Message-End-->" nil t)
			(match-beginning 0))))
	  (when (and start end)
	    (save-restriction
	      (narrow-to-region start end)
	      (goto-char (point-min))
	      (while (re-search-forward (shimbun-regexp-opt
					 '("<strong>" "</strong>" "<em>" "</em>" "</li>"))
					nil t)
		(delete-region (match-beginning 0) (match-end 0))
		(goto-char (match-beginning 0)))
	      (shimbun-decode-entities)
	      (goto-char (point-min))
	      (while (not (eobp))
		(when (looking-at "<LI>\\([^:]+\\): +")
		  (when (member (downcase (match-string 1))
				shimbun-mhonarc-optional-headers)
		    (push (cons (match-string 1)
				(shimbun-mime-encode-string
				 (buffer-substring (match-end 0)
						   (line-end-position))))
			  alist)))
		(forward-line 1))
	      (delete-region (point-min) (point-max)))
	    (save-restriction
	      (narrow-to-region (point-min) cur-point)
	      (goto-char (point-min))
	      (when (search-forward "\nMime-Version:" nil t)
		(forward-line 0)
		(dolist (p alist)
		  (insert (car p) ": " (cdr p) "\n")))
	      (goto-char (point-max)))))
	;; Processing body.
	(save-restriction
	  (narrow-to-region (point) (point-max))
	  (delete-region
	   (point)
	   (progn
	     (search-forward "\n<!--X-Body-of-Message-->\n" nil t)
	     (point)))
	  (when (search-forward "\n<!--X-Body-of-Message-End-->\n" nil t)
	    (forward-line -1)
	    (delete-region (point) (point-max)))))
    (goto-char (point-min))
    (shimbun-header-insert shimbun header)
    (insert
     "Content-Type: text/html; charset=ISO-2022-JP\nMIME-Version: 1.0\n\n"))
  (encode-coding-string (buffer-string)
			(mime-charset-to-coding-system "ISO-2022-JP")))

(provide 'sb-mhonarc)

;;; sb-mhonarc.el ends here
