;; Enhanced Pixel Art Creator NFT Contract
;; Allows users to mint NFTs with pixel art metadata, royalty system, marketplace, and more features

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-non-fungible-token pixel-art-nft uint)

;; Data variables
(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var base-uri (string-ascii 256) "https://api.pixelart.stacks/metadata/")
(define-data-var mint-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var platform-fee-percent uint u2) ;; 2% platform fee

;; Maps
(define-map token-metadata uint {
    creator: principal,
    pixel-data: (string-ascii 1000),
    royalty-percent: uint,
    creation-block: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    tags: (string-ascii 200)
})

(define-map token-listings uint {
    seller: principal,
    price: uint,
    listed-at: uint
})

(define-map approved-operators {owner: principal, operator: principal} bool)
(define-map creator-stats principal {
    total-minted: uint,
    total-earned: uint
})

(define-map collection-stats (string-ascii 50) {
    total-items: uint,
    floor-price: uint
})

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-ROYALTY (err u400))
(define-constant ERR-INVALID-PRICE (err u402))
(define-constant ERR-NOT-LISTED (err u403))
(define-constant ERR-INSUFFICIENT-FUNDS (err u405))
(define-constant ERR-TRANSFER-FAILED (err u406))

;; Read-only functions
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some (concat (var-get base-uri) (uint-to-ascii token-id))))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? pixel-art-nft token-id))
)

(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id)
)

(define-read-only (get-token-listing (token-id uint))
    (map-get? token-listings token-id)
)

(define-read-only (get-creator-stats (creator principal))
    (default-to {total-minted: u0, total-earned: u0} (map-get? creator-stats creator))
)

(define-read-only (get-collection-stats (collection-name (string-ascii 50)))
    (default-to {total-items: u0, floor-price: u0} (map-get? collection-stats collection-name))
)

(define-read-only (is-approved-operator (owner principal) (operator principal))
    (default-to false (map-get? approved-operators {owner: owner, operator: operator}))
)

(define-read-only (get-mint-fee)
    (var-get mint-fee)
)

(define-read-only (get-tokens-by-owner (owner principal))
    (let ((max-id (var-get last-token-id)))
        (filter-tokens-by-owner owner u1 max-id (list ))
    )
)

;; Private function to filter tokens by owner
(define-private (filter-tokens-by-owner (target-owner principal) (current-id uint) (max-id uint) (acc (list 500 uint)))
    (if (> current-id max-id)
        acc
        (let ((token-owner (nft-get-owner? pixel-art-nft current-id)))
            (if (is-eq (some target-owner) token-owner)
                (filter-tokens-by-owner target-owner (+ current-id u1) max-id (unwrap-panic (as-max-len? (append acc current-id) u500)))
                (filter-tokens-by-owner target-owner (+ current-id u1) max-id acc)
            )
        )
    )
)