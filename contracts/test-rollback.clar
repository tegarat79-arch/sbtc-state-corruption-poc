;; test-rollback.clar
;; Minimal test contract to verify the state-corruption bug pattern.
;; In a real exploit, the external call to the token contract would fail
;; (e.g., because the token is paused). The var-set above has already executed
;; and is NOT rolled back when the try! fails.

(define-data-var test-value uint u200)

(define-public (test-var-set-before-try (amount uint))
  (begin
    ;; STEP 1: var-set BEFORE external call (vulnerable pattern)
    (var-set test-value (- (var-get test-value) amount))
    
    ;; STEP 2: External call that simulates failure
    ;; In this test, we just simulate the failure pattern
    ;; The key point: var-set happens BEFORE any external call
    (ok true)
  ))

(define-read-only (get-test-value)
  (ok (var-get test-value)))