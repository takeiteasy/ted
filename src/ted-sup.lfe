(defmodule ted-sup
  (export
    (start_link 0)))

;;; The editor's root context. Deliberately just a patchbay_context
;;; rather than a hand-rolled supervisor module -- a top-level context is
;;; not a special case, it's the same primitive every nested context
;;; uses, registered under 'ted-root. Every editor subsystem (buffers,
;;; files, commands, keymaps, config) mounts onto it at runtime via
;;; patchbay_context:mount/2; nothing is hard-wired here.

(defun start_link ()
  (patchbay_context:start_link 'ted-root #m()))
