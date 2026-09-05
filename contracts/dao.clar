;; =============================================================================
;; Mock DAO - always returns true for check-is-protocol
;; Used to simulate an honest DAO that authorizes the call
;; =============================================================================

(define-public (check-is-protocol (caller principal))
  (ok true)
)

;; Allow the stbtc-reserve to call us via trait
(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.dao-trait)