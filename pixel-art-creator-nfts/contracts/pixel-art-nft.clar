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