;;; sb-cnn-jp.el --- shimbun backend for CNN Japan

;; Copyright (C) 2003, 2004, 2005 Tsuyoshi CHO <tsuyoshi_cho@ybb.ne.jp>

;; Author: Tsuyoshi CHO <tsuyoshi_cho@ybb.ne.jp>
;; Keywords: news
;; Created: May 22, 2004

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

;;; Code:

(require 'shimbun)
(luna-define-class shimbun-cnn-jp (shimbun-japanese-newspaper shimbun) ())

(defvar shimbun-cnn-jp-top-level-domain "cnn.co.jp"
  "Name of the top level domain for the CNN Japan.")

(defvar shimbun-cnn-jp-url
  (concat "http://www." shimbun-cnn-jp-top-level-domain "/")
  "Name of the parent url.")

(defvar shimbun-cnn-jp-server-name "CNN Japan")
(defvar shimbun-cnn-jp-from-address "webmaster@cnn.co.jp")
(defvar shimbun-cnn-jp-content-start
  "Web\\(\\s \\|&nbsp;\\)+posted\\(\\s \\|&nbsp;\\)+at:[^<]*<br>")
(defvar shimbun-cnn-jp-content-end "<div class=\"box\">")
(defvar shimbun-cnn-jp-expiration-days 14)

(defvar shimbun-cnn-jp-group-alist
  `(("top"      . ,shimbun-cnn-jp-url)
    ("world"    . ,(concat shimbun-cnn-jp-url "world/world.html"))
    ("usa"      . ,(concat shimbun-cnn-jp-url "usa/usa.html"))
    ("business" . ,(concat shimbun-cnn-jp-url "business/business.html"))
    ("sports"   . ,(concat shimbun-cnn-jp-url "sports/sports.html"))
    ("science"  . ,(concat shimbun-cnn-jp-url "science/science.html"))
    ("showbiz"  . ,(concat shimbun-cnn-jp-url "showbiz/showbiz.html"))
    ("fringe"   . ,(concat shimbun-cnn-jp-url "fringe/fringe.html"))))

(defvar shimbun-cnn-jp-x-face-alist
  '(("default" . "\
Face: iVBORw0KGgoAAAANSUhEUgAAADAAAAAWAgMAAAD7mfc/AAAABGdBTUEAALGPC/xhBQAAAAx
 QTFRFtgEB4mlp9bGx/vT0/VCoMAAAAC90RVh0U29mdHdhcmUAWFYgVmVyc2lvbiAzLjEwYStGTG1
 hc2sgIFJldjogMTIvMjkvOTQbx6p8AAAA9ElEQVR42j3OMU7DQBAF0L8TxRviIg1IhCYUES0cYbM
 FNRROJFwQSioq6oxzAgspkTgCziHiI2xD78Y9RZBAsjwZS4hmvl7z/0Da+7RO5XchoYQEpJu51Em
 HFme7JJHPZBUYP1TsFvVq832tqMaI568v2/eRolwijp4ftw9WwXyxj8bp2y0pvBOJrF/PWEEkQiZ
 bu/xOYRXIyV1CEXe4Me78H6fGnXTodRgYR/gr6JPxxjEy3gtZmnlm/SDvJ2Q582HJCFNoffnkqyn
 ja+gQ2erKHwYlGlMUH/FhSE3EEAdg1KDXakqlZ9LCii6J5DB7CROp4iPbnmrk8JWgOgAAAAd0SU1
 FB9QGBAQGEAm9iVAAAAAASUVORK5CYII=")))

(defvar shimbun-cnn-jp-prefer-text-plain t)

(luna-define-method shimbun-groups ((shimbun shimbun-cnn-jp))
  (mapcar 'car shimbun-cnn-jp-group-alist))

(luna-define-method shimbun-index-url ((shimbun shimbun-cnn-jp))
  (cdr  (assoc  (shimbun-current-group-internal shimbun)
		shimbun-cnn-jp-group-alist)))

(luna-define-method shimbun-get-headers ((shimbun shimbun-cnn-jp)
					 &optional range)
  (let ((case-fold-search t)
	(from (shimbun-from-address shimbun))
	year month day id ids headers)
    (while (re-search-forward
	    (eval-when-compile
	      (concat "<a href=\"/"
		      ;; 1. url
		      "\\("
		      ;; 2. category
		      "\\([^/]+\\)"
		      "/"
		      ;; 3. news provider
		      "\\([^./0-9]+\\)"
		      ;; 4. year
		      "\\(20[0-9][0-9]\\)"
		      ;; 5. month
		      "\\([01][0-9]\\)"
		      ;; 6. day
		      "\\([0-3][0-9]\\)"
		      ;; 7. number
		      "\\([0-9]+\\)"
		      "\\.html\\)"
		      "\">"
		      ;; 8. title
		      "\\([^>]+\\)"
		      "</a>"))
	    nil t)
      (setq year (string-to-number (match-string 4))
	    month (string-to-number (match-string 5))
	    day (string-to-number (match-string 6))
	    id (format "<%s%d%02d%02d%s%%%s@%s>"
		       (match-string 3)
		       year month day
		       (match-string 7)
		       (match-string 2)
		       shimbun-cnn-jp-top-level-domain))
      (unless (or (member id ids) ;; Avoid duplications.
		  (shimbun-search-id shimbun id))
	(push id ids)
	(push (shimbun-create-header
	       0
	       (match-string 8)
	       from
	       (shimbun-make-date-string year month day)
	       id "" 0 0
	       (shimbun-expand-url (match-string 1) shimbun-cnn-jp-url))
	      headers)))
    headers))

(defun shimbun-cnn-jp-prepare-article (shimbun header)
  "Prepare an article:
 adjusting a date header if there is a correct information available;
 move a photograph to the top."
  (let ((case-fold-search t)
	photo)
    (when (re-search-forward
	   ">\\(20[0-9][0-9]\\).\\([01][0-9]\\).\\([0-3][0-9]\\)<br>\n\
Web\\(?:\\s \\|&nbsp;\\)+posted\\(?:\\s \\|&nbsp;\\)+at:[^0-9]*\
\\([0-9][0-9]:[0-9][0-9]\\)\\(?:\\s \\|&nbsp;\\)*\\([A-Z]+\\)<br>"
	   ;; <p class="date">2005.02.10<br>
	   ;; Web&nbsp;posted&nbsp;at:&nbsp;
	   ;; 10:23
	   ;; &nbsp;JST<br>
	   nil t)
      (shimbun-header-set-date
       header
       (shimbun-make-date-string
	(string-to-number (match-string-no-properties 1))
	(string-to-number (match-string-no-properties 2))
	(string-to-number (match-string-no-properties 3))
	(match-string-no-properties 4)
	(match-string-no-properties 5)))
      (goto-char (point-min)))

    (when (and (not (shimbun-prefer-text-plain-internal shimbun))
	       (re-search-forward "<div[\t\n ]+class=\"ImgC\">[\t\n ]*\
\\(<img[\t\n ]+[^>]+>\\)[\t\n ]*</div>\
\\(?:[\t\n ]*<div[\t\n ]+class=\"pCaption\">[\t\n ]*\
<p>\\([^<]+\\)</p>[\t\n ]*</div>\\)?"
				  nil t)
	       (progn
		 (setq photo (if (match-beginning 2)
				 (concat (match-string 1) "<br>\n"
					 (match-string 2) "<br>\n")
			       (concat (match-string 1) "<br>\n")))
		 (goto-char (point-min))
		 (re-search-forward (shimbun-content-start shimbun) nil t)))
      (if (looking-at "[\t\n ]*\\(-[\t\n ]+[A-Z]+\\(?:/[A-Z]+\\)*\\)\
\[\t\n ]*</p>[\t\n ]*<p>")
	  (replace-match (concat "\\1<br>\n" photo "<p>"))
	(when (looking-at "[\t\n ]+")
	  (delete-region (match-beginning 0) (match-end 0)))
	(insert photo))
      (goto-char (point-min)))))

(luna-define-method shimbun-make-contents :before ((shimbun shimbun-cnn-jp)
						   header)
  (shimbun-cnn-jp-prepare-article shimbun header))

(provide 'sb-cnn-jp)

;;; sb-cnn-jp.el ends here
