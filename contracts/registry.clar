;; ArtifactChain - Decentralized Archaeological Artifact Verification and Provenance Platform

;; Error Constants
(define-constant ERR_ACCESS_DENIED (err u1000))
(define-constant ERR_ADMIN_ONLY (err u1001))
(define-constant ERR_DUPLICATE_RECORD (err u1002))
(define-constant ERR_RECORD_NOT_FOUND (err u1003))
(define-constant ERR_FUNDS_SHORTAGE (err u1004))
(define-constant ERR_ARTIFACT_NOT_FOUND (err u1005))
(define-constant ERR_VERIFICATION_EXPIRED (err u1006))
(define-constant ERR_NO_VERIFICATION (err u1007))
(define-constant ERR_PAYMENT_INVALID (err u1008))
(define-constant ERR_ARTIFACT_UNAVAILABLE (err u1009))
(define-constant ERR_INVALID_PRICE (err u1010))
(define-constant ERR_ALREADY_PROCESSED (err u1011))
(define-constant ERR_INVALID_DURATION (err u1012))
(define-constant ERR_LIMIT_REACHED (err u1013))
(define-constant ERR_INVALID_RATE (err u1014))
(define-constant ERR_INVALID_PERIOD (err u1015))
(define-constant ERR_INVALID_METADATA (err u1016))
(define-constant ERR_UNAUTHORIZED_VERIFIER (err u1017))
(define-constant ERR_INVALID_LOCATION (err u1018))

;; Contract Owner
(define-constant PLATFORM_ADMIN tx-sender)

;; Data Variables
(define-data-var verification-pool-balance uint u0)
(define-data-var total-registered-artifacts uint u0)
(define-data-var certification-counter uint u0)
(define-data-var platform-paused bool false)

;; Constants
(define-constant BLOCKS_PER_YEAR u52560)
(define-constant MIN_VERIFICATION_FEE u1000)
(define-constant MAX_ARTIFACT_VALUE u1000000000)
(define-constant MAX_ARTIFACTS_PER_INSTITUTION u1000)
(define-constant PLATFORM_FEE_PERCENT u5)
(define-constant MIN_VERIFIER_REPUTATION u300)

;; Principal Maps
(define-map cultural-institutions principal
    {
        verified: bool,
        artifact-count: uint,
        reputation-score: uint,
        active-status: bool,
        registration-height: uint,
        last-update-height: uint,
        total-earnings: uint
    }
)

(define-map verifiers principal
    {
        has-active-verification: bool,
        verified-artifact-id: uint,
        verification-scope: (string-ascii 64),
        annual-fee: uint,
        verification-start-height: uint,
        verification-end-height: uint,
        total-verified-artifacts: uint,
        last-verification-height: uint,
        specialization: (string-ascii 64),
        reputation-score: uint
    }
)

(define-map cultural-artifacts uint
    {
        institution-address: principal,
        historical-period: (string-ascii 64),
        verification-fee: uint,
        acquisition-price: uint,
        available-for-verification: bool,
        active-verification-count: uint,
        discovery-height: uint,
        min-verification-term: uint,
        max-verification-term: uint,
        artifact-metadata: (string-ascii 256),
        discovery-location: (string-ascii 128),
        carbon-dated: bool
    }
)

(define-map provenance-records uint
    {
        verifier-address: principal,
        payment-amount: uint,
        status: (string-ascii 20),
        processing-height: uint,
        verification-report: (string-ascii 256),
        laboratory: (optional principal),
        verification-duration: uint,
        verification-methods: (string-ascii 128)
    }
)

;; Private Functions
(define-private (check-admin-access)
    (is-eq tx-sender PLATFORM_ADMIN)
)

(define-private (validate-verification-fee (fee-amount uint))
    (>= fee-amount MIN_VERIFICATION_FEE)
)

(define-private (validate-acquisition-price (acquisition-price uint))
    (and 
        (> acquisition-price u0)
        (<= acquisition-price MAX_ARTIFACT_VALUE)
    )
)

(define-private (validate-period (historical-period (string-ascii 64)))
    (let ((period-length (len historical-period)))
        (and (> period-length u0) (<= period-length u64))
    )
)

(define-private (validate-metadata (artifact-metadata (string-ascii 256)))
    (let ((metadata-length (len artifact-metadata)))
        (and (> metadata-length u0) (<= metadata-length u256))
    )
)

(define-private (validate-location (discovery-location (string-ascii 128)))
    (let ((location-length (len discovery-location)))
        (and (> location-length u0) (<= location-length u128))
    )
)

(define-private (calculate-platform-fee (payment uint))
    (/ (* payment PLATFORM_FEE_PERCENT) u100)
)

;; Read-Only Functions
(define-read-only (get-institution-info (institution-address principal))
    (map-get? cultural-institutions institution-address)
)

(define-read-only (get-verifier-info (verifier-address principal))
    (map-get? verifiers verifier-address)
)

(define-read-only (get-artifact-info (artifact-id uint))
    (map-get? cultural-artifacts artifact-id)
)

(define-read-only (get-provenance-info (record-id uint))
    (map-get? provenance-records record-id)
)

(define-read-only (get-verification-pool)
    (var-get verification-pool-balance)
)

(define-read-only (is-platform-paused)
    (var-get platform-paused)
)

