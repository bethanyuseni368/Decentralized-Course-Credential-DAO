;; Minimal test contract
(define-constant ERR-TEST (err u100))
(define-data-var test-var uint u0)
(define-read-only (get-test) (ok (var-get test-var)))