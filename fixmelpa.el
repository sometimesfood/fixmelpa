;;; fixmelpa.el --- Fix MELPA unstable packages.

;; Copyright (C) 2014  Jorgen Schaefer <contact@jorgenschaefer.de>

;; Author: Jorgen Schaefer <contact@jorgenschaefer.de>
;; Version: 1.0

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package fixes MELPA version problems by providing a way of
;; pinning packages available from MELPA stable to that archive and
;; reinstalling packages installed from stable if they are available
;; from there.

;; To ensure that you will always install packages from MELPA stable
;; if available, add the following to your .emacs:

;; (defadvice package-refresh-contents
;;     (before ad-fixmelpa-refresh-pinned-packages activate)
;;   "Refresh pinned packages before refreshing package contents."
;;   (fixmelpa-refresh-pinned-packages))

;; To reinstall packages installed from unstable, if possible, use

;; M-x fixmelpa

;; The MELPA unstable package archive uses made-up version numbers,
;; like 20140204.291, for packages it builds. As these are usually
;; higher than the official version numbers for the respective
;; packages, this means MELPA versions will always override any other
;; archive's versions, even if the package is not available from MELPA
;; anymore, or the version on MELPA is outdated.

;; This is basically a vendor lock-in, made even worse because MELPA
;; could just have added the year + index to the end of a known
;; version number and have achieved the same effect.

;;; Code:

(require 'cl-lib)

(defun fixmelpa-refresh-pinned-packages ()
  "Pin packages in MELPA stable and unstable to stable.

This modifies `package-pinned-packages'. "
  (dolist (pair (fixmelpa-pin-stable-list))
    (add-to-list 'package-pinned-packages
                 pair
                 t)))

(defun fixmelpa-pin-stable-list ()
  "Return a list of package pinnings."
  (let ((unstable-name (fixmelpa-unstable-name))
        (stable-name (fixmelpa-stable-name))
        (result nil))
    (dolist (pair package-archive-contents)
      (let ((archives (mapcar #'package-desc-archive (cdr pair))))
        (when (and (member unstable-name archives)
                   (member stable-name archives))
          (push (cons (car pair)
                      stable-name)
                result))))
    result))

(defun fixmelpa-any-p (predicate seq)
  "Return non-nil if PREDICATE returns a non-nil value for some
element of SEQ."
  (not (null (cl-find-if predicate seq))))

(defun fixmelpa-string-match-any (regexps string)
  "Return non-nil if STRING matches any of the regular
expressions in REGEXPS."
  (fixmelpa-any-p (lambda (regexp) (string-match regexp string))
                  regexps))

(defvar fixmelpa-unstable-urls
  '("http://melpa\\.milkbox\\.net/packages"
    "http://melpa\\.org/packages")
  "List of MELPA unstable URL regexps")

(defvar fixmelpa-stable-urls
  '("http://melpa-stable\\.milkbox\\.net/packages"
    "http://stable\\.melpa\\.org/packages")
  "List of MELPA stable URL regexps")

(defun fixmelpa-repo-name (urls)
  (catch 'return
    (dolist (archive package-archives)
      (when (fixmelpa-string-match-any urls (cdr archive))
        (throw 'return (car archive))))))

(defun fixmelpa-unstable-name ()
  "Return the name of the unstable MELPA repository."
  (fixmelpa-repo-name fixmelpa-unstable-urls))

(defun fixmelpa-stable-name ()
  "Return the name of the stable MELPA repository."
  (fixmelpa-repo-name fixmelpa-stable-urls))

(defun fixmelpa-unstable-version-p (version)
  "Return non-nil if VERSION is a bogus MELPA version."
  (and (= 2 (length version))
       (> (car version)
          20000000)))

(defun fixmelpa-find-unstable-packages ()
  "Return a list of pkg-desc objects for packages installed from unstable."
  (let ((packages nil))
    (dolist (pair package-alist)
      (dolist (pkg-desc (cdr pair))
        (when (remove-melpa-melpa-version-p (package-desc-version pkg-desc))
          (push pkg-desc packages))))
    packages))

(defun fixmelpa-package-from (pkg-name archive-name)
  "Return the pkg-desc for PKG-NAME from ARCHIVE-NAME.

Return nil if the package is not available from that archive."
  (catch 'return
    (dolist (pair package-archive-contents)
      (when (eq pkg-name (car pair))
        (dolist (pkg-desc (cdr pair))
          (when (string= archive-name (package-desc-archive pkg-desc))
            (throw 'return pkg-desc)))))
    nil))

(defalias 'fixmelpa 'fixmelpa-reinstall-packages)
(defun fixmelpa-reinstall-packages ()
  "Reinstall MELPA packages from unstable to stable."
  (interactive)
  (let ((stable-name (fixmelpa-stable-name))
        (changes nil))
    (dolist (pkg-desc (fixmelpa-find-unstable-packages))
      (let ((better (fixmelpa-package-from (package-desc-name pkg-desc)
                                           stable-name)))
        (when better
          (push (format "%s %s -> %s"
                        (package-desc-name pkg-desc)
                        (package-version-join
                         (package-desc-version pkg-desc))
                        (package-version-join
                         (package-desc-version better)))
                changes)
          (package-delete pkg-desc)
          (package-install better))))
    (cond
     ((not changes)
      (message "No packages needed to be reinstalled."))
     ((= 1 (length changes))
      (message "Reinstalled %s" (car changes)))
     (t
      (with-help-window "*Fix MELPA*"
        (princ "Reinstalled the following packages from MELPA stable:")
        (terpri)
        (terpri)
        (dolist (change changes)
          (princ change)
          (terpri)))))))

(provide 'fixmelpa)
;;; fixmelpa.el ends here
