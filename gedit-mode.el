;;; gedit-mode.el --- make emacs more accessible to former gedit users -*- coding: utf-8-unix -*-

;; Copyright (C) 2013 Robert Bruce Park

;; Author   : Robert Bruce Park <r@robru.ca>
;; URL      : https://github.com/robru/gedit-mode
;; Version  : 0.1
;; Keywords : gedit, keys, keybindings, easy, cua

;; This file is NOT part of GNU Emacs.

;; gedit-mode is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation, either version 3 of the License,
;; or (at your option) any later version.

;; gedit-mode is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; INTRODUCTION
;;

;; What's this?
;;
;; It is a minor mode for Emacs. It aims to tame Emacs' archaic
;; default keybindings and make them more accessible to novice users.
;; Although titled "GEdit" mode, users of every graphical application
;; ever written should find most of these keybindings familiar. GEdit
;; was simply chosen as the namesake since that is what I was
;; primarily using before I discovered Emacs.

;; Why don't you just use GEdit if you like it so much?
;;
;; Listen buddy, I don't like your attitude!
;;
;; Seriously though, once I had a taste of Elisp, I was totally hooked
;; on Emacs. I actually tried to reimplement some basic Emacs features
;; as Python plugins inside GEdit, but gave up when I discovered that
;; a 10-line whitespace-stripping elisp snippet required 100 lines of
;; Python code to implement in GEdit.
;;
;; So, if you are a vetern Emacs ninja, this mode may be of little
;; interest to you. But if you are just starting out and you find the
;; default keybindings intimidating, then I encourage you to give this
;; a try.

;;; USAGE
;;
;; gedit-mode is now hosted on MELPA! Type `M-x package-install
;; gedit-mode`, then add the following code to your init file:
;;
;;     (require 'gedit-mode)
;;     (global-gedit-mode)

;;; TODO
;;
;; At this point, I believe that I have defined a highly accurate
;; reproduction of all of GEdit's default keybindings, at least
;; according to GEdit's official documentation. If there is anything
;; missing here, it is likely undocumented, but please do let me know
;; about it.
;;
;; I still need:
;;
;; * to think up some sensible new bindings for all the stuff that
;;   I've clobbered here.
;;
;; * to clean up some of the sr-speedbar and shell-pop config code,
;;   particularly allowing those settings to be reverted when
;;   gedit-mode is disabled.
;;
;; * define gedit-like behaviors for the tabbar.

;;; For more information
;;
;; https://help.gnome.org/users/gedit/stable/gedit-shortcut-keys.html.en

(when (require 'sr-speedbar nil :noerror)
  (setq speedbar-show-unknown-files t
        speedbar-use-images nil
        sr-speedbar-auto-refresh nil
        sr-speedbar-right-side nil)
  (when (display-graphic-p)
    (add-hook 'after-init-hook 'sr-speedbar-toggle)))

(when (require 'shell-pop nil :noerror)
  (shell-pop-set-internal-mode "term")
  (shell-pop-set-internal-mode-shell "/bin/bash")
  (shell-pop-set-window-height 20) ;; in percent
  (shell-pop-set-window-position "bottom")
  (ansi-color-for-comint-mode-on)

  (setq comint-scroll-to-bottom-on-input t
        explicit-shell-file-name "/bin/bash"
        term-input-ignoredups t
        term-scroll-show-maximum-output t))

(defvar gedit-untitled-count 1
  "This value is used to count how many untitled buffers you have open.")

(defvar gedit-orig-input-decode-map (copy-keymap input-decode-map)
  "This holds a backup copy of the input-decode-map, which we twiddle with.")

(defvar gedit-input-decode-map
  (let ((map (copy-keymap input-decode-map)))
    ;; De-prefix-ize C-x and C-c. This doesn't unbind the prefix maps
    ;; from those keys at all; it just tricks emacs into preventing
    ;; the user from being able to type C-x and C-c, replacing those
    ;; keystrokes with an entirely different keycode, which we then
    ;; bind new functionality to. For example, when you physically
    ;; type ctrl + x, emacs gets a different keycode than what was
    ;; really produced). It works for our purposes, but the
    ;; disadvantage is that <F1>b will display the C-x and C-c prefix
    ;; maps as though they are still active and reachable, which they
    ;; aren't. I would love to be shown a better way to do this, but I
    ;; haven't found it thus far.
    (define-key map [?\C-x] [C-x])
    (define-key map [?\C-c] [C-c])
    ;; So I can force these to do whatever I want, even inside isearch.
    (define-key map [?\C-g] [C-g])
    (define-key map [?\C-\S-g] [C-S-g])
    ;; Decouple ASCII codes from real keys. This lets us rebind C-i
    ;; and C-m without interfering with the bindings for TAB and RET
    ;; keys. This breaks horribly in a terminal (which can't tell the
    ;; difference between C-i vs TAB), so you only get GEdit-style C-i
    ;; and C-m keys while using graphical systems.
    (when (display-graphic-p)
      (define-key map [?\C-i] [C-i])
      (define-key map [?\C-m] [C-m])
      (define-key map [?\C-\S-m] [C-S-m]))
    map)
  "Custom input-decode-map to mimick GEdit more closely.")

(defvar gedit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-+") 'text-scale-increase)
    (define-key map (kbd "C--") 'text-scale-decrease)
    (define-key map (kbd "C-=") 'text-scale-increase)
    (define-key map (kbd "C-S-k") 'isearch-exit)
    (define-key map (kbd "C-S-l") 'gedit-save-all-buffers)
    (define-key map (kbd "C-S-s") 'write-file)
    (define-key map (kbd "C-S-w") 'gedit-kill-all-buffers)
    (define-key map (kbd "C-a") 'mark-whole-buffer)
    (define-key map (kbd "C-d") 'kill-whole-line)
    (define-key map (kbd "C-f") 'isearch-forward)
    (define-key map (kbd "C-h") 'query-replace)
    (define-key map (kbd "C-n") 'gedit-new-file)
    (define-key map (kbd "C-o") 'gedit-find-file)
    (define-key map (kbd "C-p") 'print-buffer)
    (define-key map (kbd "C-q") 'save-buffers-kill-emacs)
    (define-key map (kbd "C-s") 'save-buffer)
    (define-key map (kbd "C-v") 'cua-paste)
    (define-key map (kbd "C-w") 'gedit-kill-this-buffer-dwim)
    (define-key map (kbd "C-z") 'undo)
    (define-key map [C-M-kp-next] 'next-buffer)
    (define-key map [C-M-kp-prior] 'previous-buffer)
    (define-key map [C-M-next] 'next-buffer)
    (define-key map [C-M-prior] 'previous-buffer)
    (define-key map [C-S-g] 'isearch-repeat-backward)
    (define-key map [C-S-m] 'gedit-comment-or-uncomment-dwim)
    (define-key map [C-c] 'gedit-copy-region-or-current-line)
    (define-key map [C-f9] 'shell-pop)
    (define-key map [C-g] 'isearch-repeat-forward)
    (define-key map [C-i] 'goto-line)
    (define-key map [C-m] 'gedit-comment-or-uncomment-dwim)
    (define-key map [C-x] 'gedit-cut-region-or-current-line)
    (define-key map [M-down] 'gedit-transpose-text-down)
    (define-key map [M-f12] 'delete-trailing-whitespace)
    (define-key map [M-up] 'gedit-transpose-text-up)
    (define-key map [S-f7] 'ispell)
    (define-key map [f8] 'compile)
    (define-key map [f9] 'sr-speedbar-toggle)
    (define-key map [home] 'gedit-back-to-indentation-or-home)
    (define-key map [kp-home] 'gedit-back-to-indentation-or-home)
    map)
  "Keymap for GEdit minor mode.")

(defun gedit-move-text (arg)
  "Transpose lines/region up or down in the buffer."
   (cond
    ((and mark-active transient-mark-mode)
     (if (> (point) (mark))
            (exchange-point-and-mark))
     (let ((column (current-column))
              (text (delete-and-extract-region (point) (mark))))
       (forward-line arg)
       (move-to-column column t)
       (set-mark (point))
       (insert text)
       (exchange-point-and-mark)
       (setq deactivate-mark nil)))
    (t
     (beginning-of-line)
     (when (or (> arg 0) (not (bobp)))
       (forward-line)
       (when (or (< arg 0) (not (eobp)))
            (transpose-lines arg))
       (forward-line -1)))))

(defun gedit-transpose-text-down (arg)
   "Move regionor current line arg lines down."
   (interactive "*p")
   (gedit-move-text arg))

(defun gedit-transpose-text-up (arg)
   "Move region or current line arg lines up."
   (interactive "*p")
   (gedit-move-text (- arg)))

(defun gedit-back-to-indentation-or-home ()
  "Toggle point between beginning of line, or first non-whitespace character."
  (interactive "^")    ;; Set mark if shift key used.
  (if (looking-at "^") ;; Regex
      (back-to-indentation)
    (move-beginning-of-line nil)))

(defun gedit-region-or-line-beginning ()
  "Identifies either the beginning of the line or the region, as appropriate."
  (if (use-region-p)
      (region-beginning)
    (line-beginning-position)))

(defun gedit-region-or-line-end (&optional offset)
  "Identifies either the end of the line or the region, as appropriate."
  (if (use-region-p)
      (region-end)
    (min (+ (or offset 0)
            (line-end-position))
         (point-max))))

(defun gedit-comment-or-uncomment-whole-lines (beg end)
  "Comment or uncomment only whole lines."
  (interactive "r")
  (comment-or-uncomment-region
   (save-excursion (goto-char beg) (line-beginning-position))
   (save-excursion (goto-char end) (line-end-position))))

(defun gedit-comment-or-uncomment-dwim ()
  "Do What I Mean: Comment either the current line, or the region."
  (interactive)
  (gedit-comment-or-uncomment-whole-lines
   (gedit-region-or-line-beginning) (gedit-region-or-line-end)))

(defun gedit-cut-region-or-current-line ()
  "If no region is present, cut current line."
  (interactive)
  (if cua--rectangle
      (cua-cut-rectangle -1)
    (kill-region (gedit-region-or-line-beginning)
                 (gedit-region-or-line-end 1))))

(defun gedit-copy-region-or-current-line ()
  "If no region is present, copy current line."
  (interactive)
  (if cua--rectangle
      (cua-copy-rectangle -1)
    (copy-region-as-kill (gedit-region-or-line-beginning)
                         (gedit-region-or-line-end 1))))

(defun gedit-save-that-buffer (buffer)
  "Save the specified buffer."
  (with-current-buffer buffer (save-buffer)))

(defun gedit-save-all-buffers ()
  "Cycle through all buffers and save them."
  (interactive)
  (mapc 'gedit-save-that-buffer
        (remove-if-not 'buffer-file-name (buffer-list)))
  (message "All buffers saved."))

(defun gedit-new-file ()
  "Create a new empty buffer, untitled but numbered for uniqueness."
  (interactive)
  (switch-to-buffer
   (get-buffer-create
    (concat "Untitled Document "
            (number-to-string gedit-untitled-count))))
  (incf gedit-untitled-count))

(defun gedit-find-file ()
  "Prompt for root if opening a file for which I lack write permissions."
  (interactive)
  (let ((file (read-file-name "Find file: ")))
    (find-file (concat (if (file-writable-p file) ""
                         "/sudo:root@localhost:") file))))

(defun gedit-kill-this-buffer-dwim ()
  "Close this file and end any emacsclient sessions associated with it."
  (interactive)
  (if server-buffer-clients
      (server-edit)
    (kill-this-buffer)
    (buffer-menu)))

(defun gedit-kill-all-buffers ()
  "Close all the files."
  (interactive)
  (mapc 'kill-buffer
        (remove-if-not 'buffer-file-name (buffer-list)))
  (setq gedit-untitled-count 1)
  (gedit-new-file))

(defgroup gedit nil
  "Minor mode for using GEdit-alike keybindings in Emacs."
  :prefix "gedit-"
  :group 'convenience
  :link '(url-link "http://github.com/robru/gedit-mode"))

;;;###autoload
(define-minor-mode gedit-mode
  "Bring GEdit-like keybindings to Emacs."
  :lighter " GEdit"
  :version "0.1"
  :global t
  :keymap gedit-mode-map
  (setq input-decode-map
        (if gedit-mode
            gedit-input-decode-map
          gedit-orig-input-decode-map))
  (cua-mode gedit-mode))

;;;###autoload
(define-globalized-minor-mode global-gedit-mode gedit-mode gedit-mode)

(provide 'gedit-mode)

;;; gedit-mode.el ends here
