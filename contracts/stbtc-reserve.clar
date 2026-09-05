;; =============================================================================
;; stbtc-reserve - Vulnerable Contract
;; 
;; This is a minimal reproduction of the state corruption vulnerability
;; in the sBTC Protocol's stbtc-reserve contract:
;;   SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.stbtc-reserve
;;
;; VULNERABILITY: The function request-sbtc-for-withdrawal updates
;; the withdrawal pool (var-set) BEFORE attempting the external
;; token transfer. If the transfer fails, the state change persists,
;; corrupting the contract's internal accounting.
;; =============================================================================

(define-data-var sbtc-for-withdrawals uint u200)
(define-data-var sbtc-staking uint u0)

(define-constant ERR_RESERVED (err u22001))
(define-constant ERR_NOT_AUTHORIZED (err u4))

;; Mock DAO trait - always returns true (honest DAO)
(define-trait dao-trait
  ((check-is-protocol (principal) (response bool uint))))

;; Mock sBTC token trait
(define-trait sbtc-token-trait
  ((transfer (uint principal principal (optional (buff 34))) (response bool uint))))

;; =============================================================================
;; VULNERABLE FUNCTION: request-sbtc-for-withdrawal
;; =============================================================================
(define-public (request-sbtc-for-withdrawal (requested-sbtc uint) (receiver principal))
  (begin
    ;; Authorization check - mock DAO always returns true
    (try! (contract-call? .mock-dao check-is-protocol contract-caller))

    ;; ===== THE BUG: state update BEFORE external call =====
    (var-set sbtc-for-withdrawals (- (var-get sbtc-for-withdrawals) requested-sbtc))

    ;; External transfer - will fail if token is paused
    (try! (as-contract?
      ((with-ft .mock-token "sbtc" requested-sbtc))
      (try! (contract-call? .mock-token
                     transfer requested-sbtc tx-sender receiver none)))
    )

    ;; This line is only reached if the transfer succeeds
    (ok requested-sbtc)
  ))

;; =============================================================================
;; Read-only functions
;; =============================================================================
(define-read-only (get-sbtc-for-withdrawals)
  (ok (var-get sbtc-for-withdrawals)))

(define-read-only (get-sbtc-staking)
  (ok (var-get sbtc-staking)))