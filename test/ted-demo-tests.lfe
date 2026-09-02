(defmodule ted-demo-tests
  (behaviour ltest-unit)
  (export all))

(include-lib "ltest/include/ltest-macros.lfe")

;;; Bootstrap smoke test. It proves the three things the skeleton needs
;;; to get right before any editor code is written:
;;;
;;;   1. the application boots and its root is a discoverable
;;;      patchbay_context registered as 'ted-root;
;;;   2. a plugin mounts onto that root, registers, and is found by a
;;;      registry scan on its metadata (`kind == ted-demo`) -- the
;;;      discovery convention every real subsystem will use;
;;;   3. lasso is linked in and usable from the running node.
;;;
;;; Each test starts its own patchbay + ted application pair and drains
;;; its mailbox afterwards. patchbay's registry is a hard-named
;;; singleton, so suites must serialize around it -- ltest runs deftest
;;; bodies in one process, and a mounted plugin's terminate/2 fires a
;;; moment after application:stop, so without the drain that trailing
;;; noise lands in the next test's mailbox.
;;;
;;; LFE note: bare #m(...) map literals do not work as match patterns --
;;; use maps:get / maps:find. A bare _ inside a backquote template
;;; becomes a junk atom, not a wildcard -- use explicit (tuple ...) or a
;;; named var.

(defun with-apps (thunk)
  (application:stop 'ted)
  (application:stop 'patchbay)
  (let ((`#(ok ,_) (application:ensure_all_started 'ted)))
    (try
      (funcall thunk)
      (after
        (application:stop 'ted)
        (application:stop 'patchbay)
        (drain ())))))

(defun root-ctx ()
  (let ((`#(ok #(,pid ,_)) (patchbay_registry:lookup 'ted-root)))
    pid))

(defun drain (acc)
  (receive
    (msg (drain (cons msg acc)))
    (after 300 (lists:reverse acc))))

(deftest root-context-is-registered
  (with-apps
    (lambda ()
      (is (is_pid (root-ctx))))))

(deftest demo-plugin-mounts-and-is-discoverable-by-metadata
  (with-apps
    (lambda ()
      (let ((`#(ok ,_) (patchbay_context:mount (root-ctx) (ted-demo-service:child_spec))))
        ;; discovery convention: scan the registry, filter on kind
        (is (lists:member 'ted-demo (patchbay_registry:names)))
        (let ((`#(ok #(,_pid ,props)) (patchbay_registry:lookup 'ted-demo)))
          (is-equal 'ted-demo (maps:get 'kind props)))))))

(deftest demo-plugin-answers-a-call
  (with-apps
    (lambda ()
      (let ((`#(ok ,_) (patchbay_context:mount (root-ctx) (ted-demo-service:child_spec))))
        (is-equal '#(ok #"hi")
                  (patchbay_service:call_service 'ted-demo '#(echo #"hi") 5000))))))

(deftest lasso-is-linked-in
  (with-apps
    (lambda ()
      (is-equal 2 (lasso:line_count (lasso:from_binary #"a\nb"))))))
