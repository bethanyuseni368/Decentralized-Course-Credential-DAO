(define-constant ERR-INSUFFICIENT (err u1))

(define-constant TIER-BRONZE u1000)
(define-constant TIER-SILVER u5000)
(define-constant TIER-GOLD u10000)

(define-constant REWARD-BRONZE u10)
(define-constant REWARD-SILVER u50)
(define-constant REWARD-GOLD u150)

(define-map donors principal (tuple (total uint) (tier uint) (rewards uint)))
(define-data-var contract-total uint u0)

(define-private (get-tier (amount uint))
  (if (>= amount TIER-GOLD) TIER-GOLD (if (>= amount TIER-SILVER) TIER-SILVER (if (>= amount TIER-BRONZE) TIER-BRONZE u0)))
)

(define-private (get-reward (tier uint))
  (if (is-eq tier TIER-GOLD) REWARD-GOLD (if (is-eq tier TIER-SILVER) REWARD-SILVER (if (is-eq tier TIER-BRONZE) REWARD-BRONZE u0)))
)

(define-public (donate (amount uint))
  (if (< amount u1)
    (err ERR-INSUFFICIENT)
    (let (
      (sender tx-sender)
      (current (default-to (tuple (total u0) (tier u0) (rewards u0)) (map-get? donors sender)))
      (prev-total (get total current))
      (new-total (+ prev-total amount))
      (new-tier (get-tier new-total))
      (prev-rewards (get rewards current))
      (new-reward (get-reward new-tier))
    )
      (begin
        (map-set donors sender (tuple (total new-total) (tier new-tier) (rewards (+ prev-rewards new-reward))))
        (var-set contract-total (+ (var-get contract-total) amount))
        (ok true)
      )
    )
  )
)

(define-read-only (get-donor (addr principal))
  (map-get? donors addr)
)

(define-read-only (get-total)
  (ok (var-get contract-total))
)