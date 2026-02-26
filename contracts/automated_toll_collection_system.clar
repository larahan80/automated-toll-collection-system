;; title: automated_toll_collection_system
;; version: 1.0.0
;; summary: Smart contract for Automated Toll Collection System

(define-constant ERR-INSUFFICIENT-BALANCE u1)
(define-constant ERR-TOLL-NOT-FOUND u2)
(define-constant ERR-UNAUTHORIZED u3)
(define-constant ERR-INVALID-AMOUNT u4)
(define-constant ERR-ALREADY-PAID u5)

(define-data-var toll-owner principal tx-sender)
(define-data-var total-collected uint u0)
(define-data-var next-toll-id uint u1)

(define-map toll-stations
  { toll-id: uint }
  { 
    name: (string-ascii 50),
    location: (string-ascii 100),
    fee: uint,
    active: bool,
    created-at: uint
  }
)

(define-map vehicle-accounts
  { vehicle-id: (string-ascii 20) }
  { 
    owner: principal,
    balance: uint,
    total-paid: uint,
    last-transaction: uint
  }
)

(define-map toll-passages
  { passage-id: uint }
  { 
    vehicle-id: (string-ascii 20),
    toll-id: uint,
    amount: uint,
    timestamp: uint,
    paid: bool
  }
)

(define-public (register-toll-station (name (string-ascii 50)) (location (string-ascii 100)) (fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get toll-owner)) (err ERR-UNAUTHORIZED))
    (asserts! (> fee u0) (err ERR-INVALID-AMOUNT))
    (let ((toll-id (var-get next-toll-id)))
      (map-set toll-stations
        { toll-id: toll-id }
        { 
          name: name,
          location: location,
          fee: fee,
          active: true,
          created-at: burn-block-height
        }
      )
      (var-set next-toll-id (+ toll-id u1))
      (ok toll-id)
    )
  )
)

(define-public (add-vehicle-balance (vehicle-id (string-ascii 20)) (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (let ((existing (map-get? vehicle-accounts { vehicle-id: vehicle-id })))
      (if (is-some existing)
        (let ((account (unwrap! existing (err ERR-TOLL-NOT-FOUND))))
          (map-set vehicle-accounts
            { vehicle-id: vehicle-id }
            { 
              owner: tx-sender,
              balance: (+ (get balance account) amount),
              total-paid: (get total-paid account),
              last-transaction: burn-block-height
            }
          )
          (ok true)
        )
        (begin
          (map-set vehicle-accounts
            { vehicle-id: vehicle-id }
            { 
              owner: tx-sender,
              balance: amount,
              total-paid: u0,
              last-transaction: burn-block-height
            }
          )
          (ok true)
        )
      )
    )
  )
)

(define-public (process-toll-passage (vehicle-id (string-ascii 20)) (toll-id uint))
  (begin
    (let ((toll (map-get? toll-stations { toll-id: toll-id }))
          (account (map-get? vehicle-accounts { vehicle-id: vehicle-id })))
      (asserts! (is-some toll) (err ERR-TOLL-NOT-FOUND))
      (asserts! (is-some account) (err ERR-TOLL-NOT-FOUND))
      (let ((toll-data (unwrap! toll (err ERR-TOLL-NOT-FOUND)))
            (acct (unwrap! account (err ERR-TOLL-NOT-FOUND))))
        (asserts! (get active toll-data) (err ERR-UNAUTHORIZED))
        (asserts! (>= (get balance acct) (get fee toll-data)) (err ERR-INSUFFICIENT-BALANCE))
        (map-set vehicle-accounts
          { vehicle-id: vehicle-id }
          { 
            owner: (get owner acct),
            balance: (- (get balance acct) (get fee toll-data)),
            total-paid: (+ (get total-paid acct) (get fee toll-data)),
            last-transaction: burn-block-height
          }
        )
        (var-set total-collected (+ (var-get total-collected) (get fee toll-data)))
        (ok true)
      )
    )
  )
)

(define-public (deactivate-toll-station (toll-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get toll-owner)) (err ERR-UNAUTHORIZED))
    (let ((toll (map-get? toll-stations { toll-id: toll-id })))
      (asserts! (is-some toll) (err ERR-TOLL-NOT-FOUND))
      (let ((toll-data (unwrap! toll (err ERR-TOLL-NOT-FOUND))))
        (map-set toll-stations
          { toll-id: toll-id }
          { 
            name: (get name toll-data),
            location: (get location toll-data),
            fee: (get fee toll-data),
            active: false,
            created-at: (get created-at toll-data)
          }
        )
        (ok true)
      )
    )
  )
)

(define-read-only (get-vehicle-balance (vehicle-id (string-ascii 20)))
  (let ((account (map-get? vehicle-accounts { vehicle-id: vehicle-id })))
    (if (is-some account)
      (ok (get balance (unwrap! account (err ERR-TOLL-NOT-FOUND))))
      (err ERR-TOLL-NOT-FOUND)
    )
  )
)

(define-read-only (get-toll-station (toll-id uint))
  (let ((toll (map-get? toll-stations { toll-id: toll-id })))
    (if (is-some toll)
      (ok (unwrap! toll (err ERR-TOLL-NOT-FOUND)))
      (err ERR-TOLL-NOT-FOUND)
    )
  )
)

(define-read-only (get-total-collected)
  (ok (var-get total-collected))
)
