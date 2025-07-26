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

;; Simplified function to get tokens by owner
(define-read-only (get-tokens-by-owner (owner principal))
    (let ((max-id (var-get last-token-id)))
        (filter-owner-tokens owner u1 max-id (list ))
    )
)

;; Private function to filter tokens by owner (renamed to avoid interdependency)
(define-private (filter-owner-tokens (target-owner principal) (current-id uint) (max-id uint) (acc (list 500 uint)))
    (if (> current-id max-id)
        acc
        (let ((token-owner (nft-get-owner? pixel-art-nft current-id)))
            (if (is-eq (some target-owner) token-owner)
                (filter-owner-tokens target-owner (+ current-id u1) max-id (unwrap-panic (as-max-len? (append acc current-id) u500)))
                (filter-owner-tokens target-owner (+ current-id u1) max-id acc)
            )
        )
    )
)

;; Public functions
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (or (is-eq tx-sender sender) 
                     (is-approved-operator sender tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (nft-get-owner? pixel-art-nft token-id)) ERR-NOT-FOUND)
        ;; Remove listing if exists
        (map-delete token-listings token-id)
        (nft-transfer? pixel-art-nft token-id sender recipient)
    )
)

(define-public (mint-pixel-art 
    (recipient principal) 
    (pixel-data (string-ascii 1000)) 
    (royalty-percent uint)
    (title (string-ascii 100))
    (description (string-ascii 500))
    (tags (string-ascii 200)))
    (let
        (
            (next-id (+ (var-get last-token-id) u1))
            (mint-fee (var-get mint-fee))
        )
        (asserts! (<= royalty-percent u25) ERR-INVALID-ROYALTY)
        
        ;; Charge mint fee
        (if (> mint-fee u0)
            (try! (stx-transfer? mint-fee tx-sender (var-get contract-owner)))
            true
        )
        
        (try! (nft-mint? pixel-art-nft next-id recipient))
        (map-set token-metadata next-id {
            creator: tx-sender,
            pixel-data: pixel-data,
            royalty-percent: royalty-percent,
            creation-block: block-height,
            title: title,
            description: description,
            tags: tags
        })
        
        ;; Update creator stats
        (let ((current-stats (get-creator-stats tx-sender)))
            (map-set creator-stats tx-sender {
                total-minted: (+ (get total-minted current-stats) u1),
                total-earned: (get total-earned current-stats)
            })
        )
        
        (var-set last-token-id next-id)
        (ok next-id)
    )
)

(define-public (list-token (token-id uint) (price uint))
    (let ((token-owner (unwrap! (nft-get-owner? pixel-art-nft token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq token-owner tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> price u0) ERR-INVALID-PRICE)
        (map-set token-listings token-id {
            seller: tx-sender,
            price: price,
            listed-at: block-height
        })
        (ok true)
    )
)

(define-public (unlist-token (token-id uint))
    (let ((listing (unwrap! (map-get? token-listings token-id) ERR-NOT-LISTED)))
        (asserts! (is-eq (get seller listing) tx-sender) ERR-NOT-AUTHORIZED)
        (map-delete token-listings token-id)
        (ok true)
    )
)

(define-public (buy-token (token-id uint))
    (let 
        (
            (listing (unwrap! (map-get? token-listings token-id) ERR-NOT-LISTED))
            (price (get price listing))
            (seller (get seller listing))
            (metadata (unwrap! (get-token-metadata token-id) ERR-NOT-FOUND))
            (creator (get creator metadata))
            (royalty-percent (get royalty-percent metadata))
            (platform-fee (/ (* price (var-get platform-fee-percent)) u100))
            (royalty-fee (if (not (is-eq creator seller)) 
                           (/ (* price royalty-percent) u100) 
                           u0))
            (seller-amount (- (- price platform-fee) royalty-fee))
        )
        
        ;; Transfer payment
        (try! (stx-transfer? seller-amount tx-sender seller))
        
        ;; Pay royalty to creator if different from seller
        (if (and (> royalty-fee u0) (not (is-eq creator seller)))
            (try! (stx-transfer? royalty-fee tx-sender creator))
            true
        )
        
        ;; Pay platform fee
        (if (> platform-fee u0)
            (try! (stx-transfer? platform-fee tx-sender (var-get contract-owner)))
            true
        )
        
        ;; Transfer NFT
        (try! (nft-transfer? pixel-art-nft token-id seller tx-sender))
        
        ;; Update creator stats
        (let ((current-stats (get-creator-stats creator)))
            (map-set creator-stats creator {
                total-minted: (get total-minted current-stats),
                total-earned: (+ (get total-earned current-stats) royalty-fee)
            })
        )
        
        ;; Remove listing
        (map-delete token-listings token-id)
        (ok true)
    )
)

(define-public (set-approved-operator (operator principal) (approved bool))
    (begin
        (map-set approved-operators {owner: tx-sender, operator: operator} approved)
        (ok true)
    )
)

(define-public (batch-mint 
    (recipients (list 10 principal))
    (pixel-data-list (list 10 (string-ascii 1000)))
    (royalty-percents (list 10 uint))
    (titles (list 10 (string-ascii 100)))
    (descriptions (list 10 (string-ascii 500)))
    (tags-list (list 10 (string-ascii 200))))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (let ((result (map batch-mint-helper 
                          recipients 
                          pixel-data-list 
                          royalty-percents 
                          titles 
                          descriptions 
                          tags-list)))
            (ok result)
        )
    )
)

(define-private (batch-mint-helper 
    (recipient principal) 
    (pixel-data (string-ascii 1000)) 
    (royalty-percent uint)
    (title (string-ascii 100))
    (description (string-ascii 500))
    (tags (string-ascii 200)))
    (mint-pixel-art recipient pixel-data royalty-percent title description tags)
)

(define-public (update-token-metadata 
    (token-id uint) 
    (new-title (string-ascii 100))
    (new-description (string-ascii 500))
    (new-tags (string-ascii 200)))
    (let 
        (
            (token-owner (unwrap! (nft-get-owner? pixel-art-nft token-id) ERR-NOT-FOUND))
            (current-metadata (unwrap! (get-token-metadata token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq token-owner tx-sender) ERR-NOT-AUTHORIZED)
        (map-set token-metadata token-id (merge current-metadata {
            title: new-title,
            description: new-description,
            tags: new-tags
        }))
        (ok true)
    )
)

(define-public (burn-token (token-id uint))
    (let ((token-owner (unwrap! (nft-get-owner? pixel-art-nft token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq token-owner tx-sender) ERR-NOT-AUTHORIZED)
        ;; Remove listing if exists
        (map-delete token-listings token-id)
        ;; Remove metadata
        (map-delete token-metadata token-id)
        ;; Burn NFT
        (nft-burn? pixel-art-nft token-id tx-sender)
    )
)

;; Admin functions
(define-public (set-base-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set base-uri new-uri)
        (ok true)
    )
)

(define-public (set-mint-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set mint-fee new-fee)
        (ok true)
    )
)

(define-public (set-platform-fee (new-fee-percent uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee-percent u10) ERR-INVALID-ROYALTY) ;; Max 10% platform fee
        (var-set platform-fee-percent new-fee-percent)
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (withdraw-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (stx-transfer? amount (as-contract tx-sender) tx-sender)
    )
)

;; Utility functions - Simplified uint-to-ascii conversion
(define-read-only (uint-to-ascii (value uint))
    (if (is-eq value u0)
        "0"
        (if (<= value u9)
            (unwrap-panic (element-at "0123456789" value))
            (let ((result (fold uint-to-ascii-fold (list u1000000000 u100000000 u10000000 u1000000 u100000 u10000 u1000 u100 u10 u1) 
                                 {num: value, result: "", started: false})))
                (get result result)
            )
        )
    )
)

(define-private (uint-to-ascii-fold (place-value uint) (acc {num: uint, result: (string-ascii 39), started: bool}))
    (let ((digit (/ (get num acc) place-value))
          (remainder (mod (get num acc) place-value)))
        (if (or (> digit u0) (get started acc))
            {
                num: remainder,
                result: (unwrap-panic (as-max-len? (concat (get result acc) (unwrap-panic (element-at "0123456789" digit))) u39)),
                started: true
            }
            acc
        )
    )
)