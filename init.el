(require 'package)
(add-to-list 'package-archives '("melpa-stable" . "http://melpa-stable.milkbox.net/packages/"))
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/"))
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/"))


;;;; General Settings (Pre-Package Loading)

(setq inhibit-startup-message t) ;; No splash screen
(setq initial-scratch-message nil) ;; No scratch message

;; Default window size
(add-to-list 'default-frame-alist '(height . 50))
(add-to-list 'default-frame-alist '(width . 180))

;; Create backup files in .emacs-backup instead of everywhere
(defvar user-temporary-file-directory "~/.emacs-backup")
(make-directory user-temporary-file-directory t)
(setq backup-by-copying t) 
(setq backup-directory-alist 
      `(("." . ,user-temporary-file-directory)
        (,tramp-file-name-regexp nil)))
(setq auto-save-list-file-prefix
      (concat user-temporary-file-directory ".auto-saves-"))
(setq auto-save-file-name-transforms
      `((".*" ,user-temporary-file-directory t)))

;; Change method of resolving duplicate buffer names
(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)

;; Enable ido and it's fancy tab completion
(ido-mode t)
(setq ido-enable-flex-matching t)

;; Font size scaling
(define-key global-map (kbd "C-+") 'text-scale-increase)
(define-key global-map (kbd "C--") 'text-scale-decrease)

;; Automatically uncompress files for editing
(auto-compression-mode 1)

;;;; Package Installation and Refresh

;; Initialize all the ELPA packages
(package-initialize)
(defvar my-packages '(cider
                      clojure-mode
                      clojure-test-mode
                      auto-complete
                      ac-nrepl
                      paredit
                      smartparens
                      popup
                      rainbow-delimiters
                      rainbow-mode
                      markdown-mode
                      noctilux-theme))

;; Install any packages from the list above which are missing
(package-refresh-contents)
(dolist (p my-packages)
  (when (not (package-installed-p p))
    (package-install p)))


;;;; General Settings (Post-Package Loading)

;; General Auto-Complete
(require 'auto-complete-config)
(setq ac-delay 0.0)
(setq ac-quick-help-delay 0.5)
(ac-config-default)

;; Show parenthesis mode
(show-paren-mode 1)

;; rainbow delimiters
(global-rainbow-delimiters-mode)

;; Noctilus Theme
(load-theme 'noctilux t)

;; Switch frame using F8
(global-set-key [f8] 'other-frame)
(global-set-key [f7] 'paredit-mode)
(global-set-key [f9] 'cider-jack-in)
(global-set-key [f11] 'speedbar)


;;;; Clojure Settings

;; Cider & nREPL
(add-hook 'clojure-mode-hook 'turn-on-eldoc-mode)
(add-hook 'clojure-mode-hook 'cider-mode)
(setq nrepl-popup-stacktraces nil)
(setq nrepl-hide-special-buffers t)
(add-to-list 'same-window-buffer-names "<em>nrepl</em>")

;; ac-nrepl (Auto-complete for the nREPL)
(require 'ac-nrepl)
(add-hook 'cider-mode-hook 'ac-nrepl-setup)
(add-hook 'cider-mode-hook 'rainbow-delimiters-mode)
(add-hook 'cider-mode-hook 'smartparens-strict-mode)

(add-hook 'cider-repl-mode-hook 'ac-nrepl-setup)
(add-hook 'cider-repl-mode-hook 'rainbow-delimiters-mode)
(add-hook 'cider-repl-mode-hook 'smartparens-strict-mode)

(add-to-list 'ac-modes 'cider-mode)
(add-to-list 'ac-modes 'cider-repl-mode)

;; Automatically indent new lines to correct depth
(add-hook 'cider-mode-hook '(lambda () (local-set-key (kbd "RET") 'newline-and-indent)))

;; Popping-up contextual documentation
(eval-after-load "cider"
  '(define-key cider-mode-map (kbd "C-c C-d") 'ac-nrepl-popup-doc))

