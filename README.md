# Fix MELPA

This package for Emacs fixes MELPA version problems by providing a way
of pinning packages available from MELPA stable to that archive and
reinstalling packages installed from stable if they are available from
there.

To ensure that you will always install packages from MELPA stable
if available, add the following to your .emacs:

```Lisp
(defadvice package-refresh-contents
    (before ad-fixmelpa-refresh-pinned-packages)
  "Refresh pinned packages before refreshing package contents."
  (fixmelpa-refresh-pinned-packages))
```

To reinstall packages installed from unstable, if possible, use

```
M-x fixmelpa
```

The MELPA unstable package archive uses made-up version numbers,
like 20140204.291, for packages it builds. As these are usually
higher than the official version numbers for the respective
packages, this means MELPA versions will always override any other
archive's versions, even if the package is not available from MELPA
anymore, or the version on MELPA is outdated.

This is basically a vendor lock-in, made even worse because MELPA
could just have added the year + index to the end of a known
version number and have achieved the same effect.
