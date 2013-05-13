;;; gedit-mode.el --- Emulate the look & feel of GEdit in Emacs

;; Copyright (C) 2013 Robert Bruce Park

;; Author: Robert Bruce Park <r@robru.ca>
;; URL: https://github.com/robru/gedit-mode
;; Version: 0.1
;; Keywords: gedit, keys, keybindings, easy, cua
;; Package-Requires: ((tabbar "0") (sr-speedbar "0") (shell-pop "0") (move-text "0"))

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
;;
;; For the complete experience, you'll want sr-speedbar, shell-pop,
;; and tabbar packages. I've listed those as requirements above,
;; although the code I've written here is smart enough not to explode
;; if they're missing. I also personally recommend visual-regexp and
;; ace-jump-mode, although those have nothing to do with GEdit ;-)

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

;;; For more information
;;
;; https://help.gnome.org/users/gedit/stable/gedit-shortcut-keys.html.en

(defvar gedit-idle-timer nil
  "The value of the idle timer we use for refreshing the speedbar.")

(defconst gedit-untitled-prefix "Untitled Document "
  "Name new buffers by appending an integer to this value.")

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
    ;; This section is the faithful recreation of GEdit keybindings.
    (define-key map [remap newline] 'newline-and-indent)
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
    (define-key map [M-f12] 'delete-trailing-whitespace)
    (define-key map [S-f7] 'ispell)
    (define-key map [f8] 'compile)
    (define-key map [f9] 'sr-speedbar-toggle)
    (define-key map [home] 'gedit-back-to-indentation-or-home)
    (define-key map [kp-home] 'gedit-back-to-indentation-or-home)

    ;; These keybindings aren't actually present in GEdit, but in my
    ;; opinion complement GEdit's defaults nicely.
    (define-key map (kbd "C-<tab>") 'next-buffer)
    (define-key map (kbd "C-S-<iso-lefttab>") 'previous-buffer)
    (define-key map (kbd "C-S-<tab>") 'previous-buffer)
    (define-key map (kbd "C-S-n") 'make-frame-command)
    (define-key map (kbd "C-b") 'buffer-menu)
    (define-key map (kbd "C-t") 'shell-pop)
    (define-key map (kbd "M-d") 'just-one-space)
    (define-key map (kbd "M-f") 'rgrep)
    (define-key map (kbd "M-i") 'imenu)
    (define-key map (kbd "M-o") 'occur)
    (define-key map (kbd "M-s") 'gedit-save-all-buffers)
    (define-key map (kbd "M-w") 'gedit-kill-all-buffers)
    map)
  "Keymap for GEdit minor mode.")

(when (require 'visual-regexp nil :noerror)
  (substitute-key-definition 'query-replace 'vr/query-replace gedit-mode-map))

(when (require 'move-text nil :noerror)
  (define-key gedit-mode-map [M-down] 'move-text-down)
  (define-key gedit-mode-map [M-up] 'move-text-up))

(when (require 'tabbar nil :noerror)
  (substitute-key-definition 'next-buffer 'tabbar-forward-tab gedit-mode-map)
  (substitute-key-definition 'previous-buffer 'tabbar-backward-tab gedit-mode-map)
  (setq tabbar-buffer-groups-function 'gedit-tabbar-buffer-groups
        tabbar-buffer-list-function 'gedit-tabbar-buffer-list)
  (defadvice tabbar-buffer-tab-label (after fixup_tab_label_space activate)
    "Add spaces around tab names for better readability."
    (setq ad-return-value (concat " " ad-return-value " ")))
  (set-face-attribute 'tabbar-separator nil
                      :height 1
                      :inherit 'mode-line
                      :box nil)
  (set-face-attribute 'tabbar-default nil
                      :inherit 'mode-line
                      :box nil)
  (set-face-attribute 'tabbar-button nil
                      :inherit 'mode-line
                      :box nil)
  (set-face-attribute 'tabbar-selected nil
                      :inherit 'mode-line-buffer-id
                      :box nil)
  (set-face-attribute 'tabbar-unselected nil
                      :inherit 'mode-line-inactive
                      :box nil)
  (add-hook 'global-gedit-mode-hook
            (lambda () (tabbar-mode (if global-gedit-mode 1 -1)))))

(when (require 'sr-speedbar nil :noerror)
  (setq speedbar-show-unknown-files t
        speedbar-use-images nil
        sr-speedbar-auto-refresh nil
        sr-speedbar-right-side nil)
  (when (display-graphic-p)
    (add-hook 'after-init-hook 'sr-speedbar-open)))

(when (require 'shell-pop nil :noerror)
  (shell-pop-set-internal-mode "term")
  (shell-pop-set-internal-mode-shell "/bin/bash")
  (shell-pop-set-window-height 20) ;; in percent
  (shell-pop-set-window-position "top")
  (ansi-color-for-comint-mode-on)

  (setq comint-scroll-to-bottom-on-input t
        explicit-shell-file-name "/bin/bash"
        term-input-ignoredups t
        term-scroll-show-maximum-output t))

(when (require 'ace-jump-mode nil :noerror)
  (define-key gedit-mode-map (kbd "C-j") 'ace-jump-mode))

;; The cl.el controversy is older than I am. I tried to avoid using
;; it, however I was disgusted to learn how many modules reimplement
;; its functions. I've decided that code reuse is a worthier goal than
;; some kind of misguided vision of technical "purity".
(require 'cl)

(defun gedit-tabbar-buffer-list ()
  "Hide the speedbar, because it's not helpful to tab to."
  (remove-if
   (lambda (buffer) (string= "*SPEEDBAR*" (buffer-name buffer)))
   (tabbar-buffer-list)))

(defun gedit-tabbar-buffer-groups ()
  "Group Emacs special buffers separately than file-related buffers."
  (list (cond ((buffer-file-name (current-buffer)) "files")
              ((gedit-buffer-untitled-p (current-buffer)) "files")
              (t "emacs"))))

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
  (let ((to-save (remove-if-not 'buffer-file-name
                                (remove-if-not 'buffer-modified-p
                                               (buffer-list)))))
    (mapc 'gedit-save-that-buffer to-save)
    (message (concat "Wrote " (mapconcat 'buffer-name to-save ", ")))))

(defun gedit-new-file ()
  "Create a new empty buffer, untitled but numbered for uniqueness."
  (interactive)
  (incf gedit-untitled-count)
  (switch-to-buffer
   (get-buffer-create
    (concat gedit-untitled-prefix
            (number-to-string gedit-untitled-count))))
  (text-mode))

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
    (kill-this-buffer)))

(defun gedit-buffer-untitled-p (buffer)
  "Is this buffer untitled?"
  (or (string-prefix-p gedit-untitled-prefix (buffer-name buffer))
      (string= "*scratch*" (buffer-name buffer))))

(defun gedit-kill-certain-buffers (predicate)
  "Kill all buffers matching predicate, except ones with unsaved changes."
  (mapc 'kill-buffer
        (remove-if 'buffer-modified-p
                   (remove-if-not predicate (buffer-list)))))

(defun gedit-kill-untitled-buffers ()
  "Close untitled (but unmodified) buffers."
  (gedit-kill-certain-buffers 'gedit-buffer-untitled-p)
  (setq gedit-untitled-count 0))

(defun gedit-kill-all-buffers ()
  "Close all the files."
  (interactive)
  (gedit-kill-certain-buffers 'buffer-file-name)
  (gedit-kill-untitled-buffers)
  (gedit-new-file))

(defun gedit-speedbar-refresh ()
  "Show new files in the speedbar."
  (when (display-graphic-p)
    (with-current-buffer (get-buffer-create "*SPEEDBAR*")
      (speedbar-refresh))))

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

(require 'server)
(unless (server-running-p)
  (server-start))

(add-hook 'global-gedit-mode-hook
          (lambda ()
            "Set mode state only when enabling or disabling globally."
            ;; Disable timer because it screws up the tag display.
            ;; (if global-gedit-mode
            ;;     (setq gedit-idle-timer
            ;;           (run-with-idle-timer 1 :repeat 'gedit-speedbar-refresh))
            ;;   (cancel-timer gedit-idle-timer))

            (gedit-kill-untitled-buffers)

            (when global-gedit-mode
              (add-hook 'find-file-hook 'gedit-kill-untitled-buffers))

            (unless global-gedit-mode
              (remove-hook 'find-file-hook 'gedit-kill-untitled-buffers))

            (switch-to-buffer
             (get-buffer-create
              (if global-gedit-mode
                  (concat gedit-untitled-prefix "1")
                "*scratch*")))))

(provide 'gedit-mode)

;;; gedit-mode.el ends here
