(defmodule ted-demo-service
  (export
    (child_spec 0)
    (service_name 0)
    (dependencies 0)
    (metadata 0)
    (init 1)
    (handle_message 2)
    (terminate 2)))

;;; The vertical-slice plugin (see docs/plugins.md). It carries no editor
;;; behaviour -- it exists to prove the plugin path end to end: mount
;;; onto 'ted-root, register in the patchbay registry, be discoverable by
;;; a registry scan for `kind == ted-demo`, and answer a call. It is also
;;; the template docs/plugins.md walks through. Real subsystems
;;; (ted-buffer-manager, ted-file, ted-command, ...) follow the same
;;; shape.
;;;
;;; Declares no dependencies, so patchbay_service transitions it straight
;;; to 'ready in init/1 -- there is no one to wait for.

(defun child_spec ()
  `#m(id ted-demo
      start #(patchbay_service start_link (ted-demo-service #m()))
      restart transient
      shutdown 5000
      type worker
      modules (patchbay_service)))

(defun service_name () 'ted-demo)
(defun dependencies () '())

(defun metadata ()
  ;;; Published as registration props (patchbay_service metadata/0); this
  ;;; is what makes the plugin discoverable via kind=ted-demo.
  (describe))

(defun init (_args) `#(ok #m()))

(defun describe ()
  #m(kind ted-demo
     name 'ted-demo
     summary #"Vertical-slice plugin -- proves the mount/register/discover/call path"))

(defun handle_message
  (('describe state) `#(reply ,(describe) ,state))
  ((`#(echo ,payload) state) `#(reply #(ok ,payload) ,state))
  ((_msg state) `#(reply #(error unknown_message) ,state)))

(defun terminate (_reason _state) 'ok)
