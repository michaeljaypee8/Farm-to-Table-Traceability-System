(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-FARM-NOT-FOUND (err u101))
(define-constant ERR-PRODUCT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-BATCH (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-CERTIFICATION (err u105))
(define-constant ERR-TRANSFER-NOT-ALLOWED (err u106))

(define-data-var next-farm-id uint u1)
(define-data-var next-product-id uint u1)
(define-data-var next-batch-id uint u1)

(define-map farms
    { farm-id: uint }
    {
        owner: principal,
        name: (string-ascii 50),
        location: (string-ascii 100),
        certified-organic: bool,
        registration-block: uint,
        active: bool
    }
)

(define-map products
    { product-id: uint }
    {
        farm-id: uint,
        name: (string-ascii 50),
        category: (string-ascii 30),
        harvest-date: uint,
        expiry-date: uint,
        quantity: uint,
        unit: (string-ascii 20),
        current-owner: principal,
        created-block: uint
    }
)

(define-map batches
    { batch-id: uint }
    {
        product-id: uint,
        farm-id: uint,
        quantity: uint,
        status: (string-ascii 20),
        current-location: (string-ascii 100),
        current-handler: principal,
        created-at: uint,
        last-updated: uint
    }
)

(define-map certifications
    { cert-id: uint }
    {
        farm-id: uint,
        cert-type: (string-ascii 30),
        issued-by: (string-ascii 50),
        valid-until: uint,
        verified: bool
    }
)

(define-map batch-history
    { batch-id: uint, sequence: uint }
    {
        handler: principal,
        location: (string-ascii 100),
        status: (string-ascii 20),
        timestamp: uint,
        notes: (string-ascii 200)
    }
)

(define-map farm-owners
    { owner: principal }
    { farm-id: uint }
)

(define-data-var next-cert-id uint u1)
(define-data-var authorized-certifiers (list 10 principal) (list))

(define-public (register-farm (name (string-ascii 50)) (location (string-ascii 100)) (organic bool))
    (let
        (
            (farm-id (var-get next-farm-id))
            (current-block stacks-block-height)
        )
        (asserts! (is-none (map-get? farm-owners { owner: tx-sender })) ERR-ALREADY-EXISTS)
        (map-set farms
            { farm-id: farm-id }
            {
                owner: tx-sender,
                name: name,
                location: location,
                certified-organic: organic,
                registration-block: current-block,
                active: true
            }
        )
        (map-set farm-owners { owner: tx-sender } { farm-id: farm-id })
        (var-set next-farm-id (+ farm-id u1))
        (ok farm-id)
    )
)

(define-public (add-product (farm-id uint) (name (string-ascii 50)) (category (string-ascii 30)) 
                           (harvest-date uint) (expiry-date uint) (quantity uint) (unit (string-ascii 20)))
    (let
        (
            (product-id (var-get next-product-id))
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR-FARM-NOT-FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get owner farm-data)) ERR-NOT-AUTHORIZED)
        (asserts! (get active farm-data) ERR-FARM-NOT-FOUND)
        (map-set products
            { product-id: product-id }
            {
                farm-id: farm-id,
                name: name,
                category: category,
                harvest-date: harvest-date,
                expiry-date: expiry-date,
                quantity: quantity,
                unit: unit,
                current-owner: tx-sender,
                created-block: current-block
            }
        )
        (var-set next-product-id (+ product-id u1))
        (ok product-id)
    )
)

(define-public (create-batch (product-id uint) (quantity uint) (initial-location (string-ascii 100)))
    (let
        (
            (batch-id (var-get next-batch-id))
            (product-data (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
            (current-time stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get current-owner product-data)) ERR-NOT-AUTHORIZED)
        (asserts! (<= quantity (get quantity product-data)) ERR-INVALID-BATCH)
        (map-set batches
            { batch-id: batch-id }
            {
                product-id: product-id,
                farm-id: (get farm-id product-data),
                quantity: quantity,
                status: "harvested",
                current-location: initial-location,
                current-handler: tx-sender,
                created-at: current-time,
                last-updated: current-time
            }
        )
        (map-set batch-history
            { batch-id: batch-id, sequence: u0 }
            {
                handler: tx-sender,
                location: initial-location,
                status: "harvested",
                timestamp: current-time,
                notes: "Initial batch creation"
            }
        )
        (var-set next-batch-id (+ batch-id u1))
        (ok batch-id)
    )
)

(define-public (transfer-batch (batch-id uint) (new-handler principal) (new-location (string-ascii 100)) 
                              (status (string-ascii 20)) (notes (string-ascii 200)))
    (let
        (
            (batch-data (unwrap! (map-get? batches { batch-id: batch-id }) ERR-INVALID-BATCH))
            (current-time stacks-block-height)
            (history-count (get-batch-history-count batch-id))
        )
        (asserts! (is-eq tx-sender (get current-handler batch-data)) ERR-NOT-AUTHORIZED)
        (map-set batches
            { batch-id: batch-id }
            (merge batch-data {
                current-location: new-location,
                current-handler: new-handler,
                status: status,
                last-updated: current-time
            })
        )
        (map-set batch-history
            { batch-id: batch-id, sequence: history-count }
            {
                handler: new-handler,
                location: new-location,
                status: status,
                timestamp: current-time,
                notes: notes
            }
        )
        (ok true)
    )
)

(define-public (add-certification (farm-id uint) (cert-type (string-ascii 30)) (issued-by (string-ascii 50)) (valid-until uint))
    (let
        (
            (cert-id (var-get next-cert-id))
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR-FARM-NOT-FOUND))
        )
        (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                     (is-some (index-of (var-get authorized-certifiers) tx-sender))) ERR-NOT-AUTHORIZED)
        (map-set certifications
            { cert-id: cert-id }
            {
                farm-id: farm-id,
                cert-type: cert-type,
                issued-by: issued-by,
                valid-until: valid-until,
                verified: true
            }
        )
        (var-set next-cert-id (+ cert-id u1))
        (ok cert-id)
    )
)

(define-public (authorize-certifier (certifier principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set authorized-certifiers 
            (unwrap! (as-max-len? (append (var-get authorized-certifiers) certifier) u10) 
                    (err u107)))
        (ok true)
    )
)

(define-public (deactivate-farm (farm-id uint))
    (let
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR-FARM-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get owner farm-data)) ERR-NOT-AUTHORIZED)
        (map-set farms
            { farm-id: farm-id }
            (merge farm-data { active: false })
        )
        (ok true)
    )
)

(define-read-only (get-farm (farm-id uint))
    (map-get? farms { farm-id: farm-id })
)

(define-read-only (get-product (product-id uint))
    (map-get? products { product-id: product-id })
)

(define-read-only (get-batch (batch-id uint))
    (map-get? batches { batch-id: batch-id })
)

(define-read-only (get-certification (cert-id uint))
    (map-get? certifications { cert-id: cert-id })
)

(define-read-only (get-farm-by-owner (owner principal))
    (map-get? farm-owners { owner: owner })
)

(define-read-only (get-batch-history (batch-id uint) (sequence uint))
    (map-get? batch-history { batch-id: batch-id, sequence: sequence })
)

(define-read-only (is-farm-organic (farm-id uint))
    (match (map-get? farms { farm-id: farm-id })
        farm-data (get certified-organic farm-data)
        false
    )
)

(define-read-only (get-product-origin (product-id uint))
    (match (map-get? products { product-id: product-id })
        product-data 
            (match (map-get? farms { farm-id: (get farm-id product-data) })
                farm-data (some { farm-name: (get name farm-data), 
                                location: (get location farm-data),
                                organic: (get certified-organic farm-data) })
                none
            )
        none
    )
)

(define-read-only (verify-batch-authenticity (batch-id uint))
    (match (map-get? batches { batch-id: batch-id })
        batch-data
            (let
                (
                    (product-data (unwrap! (map-get? products { product-id: (get product-id batch-data) }) false))
                    (farm-data (unwrap! (map-get? farms { farm-id: (get farm-id batch-data) }) false))
                )
                (and (get active farm-data) 
                     (< stacks-block-height (get expiry-date product-data)))
            )
        false
    )
)

(define-private (get-batch-history-count (batch-id uint))
    (fold count-history-entries (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) u0)
)

(define-private (count-history-entries (sequence uint) (current-count uint))
    (if (is-some (map-get? batch-history { batch-id: u0, sequence: sequence }))
        (+ current-count u1)
        current-count
    )
)
