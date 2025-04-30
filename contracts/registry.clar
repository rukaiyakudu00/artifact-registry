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

;; Public Functions

;; Register as a cultural institution
(define-public (register-institution)
    (let (
        (existing-institution (map-get? cultural-institutions tx-sender))
        (current-height block-height)
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (is-none existing-institution) ERR_DUPLICATE_RECORD)
    (map-set cultural-institutions tx-sender
        {
            verified: true,
            artifact-count: u0,
            reputation-score: u100,
            active-status: true,
            registration-height: current-height,
            last-update-height: current-height,
            total-earnings: u0
        }
    )
    (ok true))
)

;; Register as an artifact verifier
(define-public (register-verifier (specialization (string-ascii 64)))
    (let (
        (existing-verifier (map-get? verifiers tx-sender))
        (current-height block-height)
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (is-none existing-verifier) ERR_DUPLICATE_RECORD)
    (map-set verifiers tx-sender
        {
            has-active-verification: false,
            verified-artifact-id: u0,
            verification-scope: "",
            annual-fee: u0,
            verification-start-height: u0,
            verification-end-height: u0,
            total-verified-artifacts: u0,
            last-verification-height: u0,
            specialization: specialization,
            reputation-score: u300
        }
    )
    (ok true))
)

;; Register a cultural artifact
(define-public (register-cultural-artifact 
    (historical-period (string-ascii 64)) 
    (verification-fee uint) 
    (acquisition-price uint)
    (min-term uint)
    (max-term uint)
    (artifact-metadata (string-ascii 256))
    (discovery-location (string-ascii 128))
    (carbon-dated bool)
)
    (let (
        (institution-info (unwrap! (map-get? cultural-institutions tx-sender) ERR_RECORD_NOT_FOUND))
        (new-artifact-id (var-get total-registered-artifacts))
        (current-height block-height)
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (get verified institution-info) ERR_ACCESS_DENIED)
    (asserts! (get active-status institution-info) ERR_ACCESS_DENIED)
    (asserts! (< (get artifact-count institution-info) MAX_ARTIFACTS_PER_INSTITUTION) ERR_LIMIT_REACHED)
    (asserts! (validate-verification-fee verification-fee) ERR_INVALID_RATE)
    (asserts! (validate-acquisition-price acquisition-price) ERR_PAYMENT_INVALID)
    (asserts! (>= max-term min-term) ERR_INVALID_DURATION)
    (asserts! (validate-period historical-period) ERR_INVALID_PERIOD)
    (asserts! (validate-metadata artifact-metadata) ERR_INVALID_METADATA)
    (asserts! (validate-location discovery-location) ERR_INVALID_LOCATION)
    
    (map-set cultural-artifacts new-artifact-id
        {
            institution-address: tx-sender,
            historical-period: historical-period,
            verification-fee: verification-fee,
            acquisition-price: acquisition-price,
            available-for-verification: true,
            active-verification-count: u0,
            discovery-height: current-height,
            min-verification-term: min-term,
            max-verification-term: max-term,
            artifact-metadata: artifact-metadata,
            discovery-location: discovery-location,
            carbon-dated: carbon-dated
        }
    )
    
    ;; Update institution's artifact count
    (map-set cultural-institutions tx-sender
        (merge institution-info { 
            artifact-count: (+ (get artifact-count institution-info) u1),
            last-update-height: current-height
        })
    )
    
    (var-set total-registered-artifacts (+ new-artifact-id u1))
    (ok new-artifact-id))
)

;; Request artifact verification
(define-public (request-artifact-verification (artifact-id uint) (verification-term uint) (verification-scope (string-ascii 64)))
    (let (
        (artifact-info (unwrap! (map-get? cultural-artifacts artifact-id) ERR_ARTIFACT_NOT_FOUND))
        (institution-info (unwrap! (map-get? cultural-institutions (get institution-address artifact-info)) ERR_RECORD_NOT_FOUND))
        (verifier-info (unwrap! (map-get? verifiers tx-sender) ERR_UNAUTHORIZED_VERIFIER))
        (current-height block-height)
        (annual-fee (get verification-fee artifact-info))
        (term-fee (* annual-fee verification-term))
        (platform-fee (calculate-platform-fee term-fee))
        (institution-payment (- term-fee platform-fee))
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (get available-for-verification artifact-info) ERR_ARTIFACT_UNAVAILABLE)
    (asserts! (>= (get reputation-score verifier-info) MIN_VERIFIER_REPUTATION) ERR_UNAUTHORIZED_VERIFIER)
    (asserts! (and 
        (>= verification-term (get min-verification-term artifact-info))
        (<= verification-term (get max-verification-term artifact-info))
    ) ERR_INVALID_DURATION)
    
    ;; Process payment
    (try! (stx-transfer? term-fee tx-sender (get institution-address artifact-info)))
    
    ;; Update verification pool
    (var-set verification-pool-balance (+ (var-get verification-pool-balance) platform-fee))
    
    ;; Update verifier record
    (map-set verifiers tx-sender
        (merge verifier-info {
            has-active-verification: true,
            verified-artifact-id: artifact-id,
            verification-scope: verification-scope,
            annual-fee: annual-fee,
            verification-start-height: current-height,
            verification-end-height: (+ current-height (* verification-term BLOCKS_PER_YEAR)),
            total-verified-artifacts: (+ (get total-verified-artifacts verifier-info) u1),
            last-verification-height: current-height
        })
    )
    
    ;; Update artifact verification count
    (map-set cultural-artifacts artifact-id
        (merge artifact-info { active-verification-count: (+ (get active-verification-count artifact-info) u1) })
    )
    
    ;; Update institution earnings
    (map-set cultural-institutions (get institution-address artifact-info)
        (merge institution-info { 
            total-earnings: (+ (get total-earnings institution-info) institution-payment),
            last-update-height: current-height
        })
    )
    
    (ok true))
)

;; Submit verification report
(define-public (submit-verification-report 
    (payment-amount uint) 
    (verification-report (string-ascii 256))
    (verification-methods (string-ascii 128))
)
    (let (
        (verifier-info (unwrap! (map-get? verifiers tx-sender) ERR_UNAUTHORIZED_VERIFIER))
        (artifact-info (unwrap! (map-get? cultural-artifacts (get verified-artifact-id verifier-info)) ERR_ARTIFACT_NOT_FOUND))
        (new-record-id (var-get certification-counter))
        (current-height block-height)
        (platform-fee (calculate-platform-fee payment-amount))
        (institution-payment (- payment-amount platform-fee))
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (get has-active-verification verifier-info) ERR_NO_VERIFICATION)
    (asserts! (<= current-height (get verification-end-height verifier-info)) ERR_VERIFICATION_EXPIRED)
    (asserts! (validate-metadata verification-report) ERR_INVALID_METADATA)
    
    ;; Process additional payment if provided
    (when (> payment-amount u0)
        (try! (stx-transfer? payment-amount tx-sender (get institution-address artifact-info)))
        
        ;; Update institution earnings
        (let ((institution-info (unwrap! (map-get? cultural-institutions (get institution-address artifact-info)) ERR_RECORD_NOT_FOUND)))
            (map-set cultural-institutions (get institution-address artifact-info)
                (merge institution-info { 
                    total-earnings: (+ (get total-earnings institution-info) institution-payment),
                    last-update-height: current-height
                })
            )
        )
        
        ;; Update verification pool
        (var-set verification-pool-balance (+ (var-get verification-pool-balance) platform-fee))
    )
    
    ;; Create new provenance record
    (map-set provenance-records new-record-id
        {
            verifier-address: tx-sender,
            payment-amount: payment-amount,
            status: "VERIFIED",
            processing-height: current-height,
            verification-report: verification-report,
            laboratory: none,
            verification-duration: u0,
            verification-methods: verification-methods
        }
    )
    
    ;; Update reputation score
    (map-set verifiers tx-sender
        (merge verifier-info { 
            reputation-score: (+ (get reputation-score verifier-info) u10),
            last-verification-height: current-height
        })
    )
    
    ;; Update counter
    (var-set certification-counter (+ new-record-id u1))
    (ok new-record-id))
)

;; Add laboratory verification
(define-public (add-laboratory-verification (record-id uint) (laboratory-principal principal) (verification-duration uint))
    (let (
        (record-info (unwrap! (map-get? provenance-records record-id) ERR_RECORD_NOT_FOUND))
        (verifier-info (unwrap! (map-get? verifiers tx-sender) ERR_UNAUTHORIZED_VERIFIER))
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (is-eq tx-sender (get verifier-address record-info)) ERR_ACCESS_DENIED)
    (asserts! (is-none (get laboratory record-info)) ERR_ALREADY_PROCESSED)
    
    ;; Update provenance record with laboratory info
    (map-set provenance-records record-id
        (merge record-info { 
            laboratory: (some laboratory-principal),
            verification-duration: verification-duration,
            status: "LAB_VERIFIED"
        })
    )
    
    ;; Update verifier reputation for adding lab verification
    (map-set verifiers tx-sender
        (merge verifier-info { 
            reputation-score: (+ (get reputation-score verifier-info) u5)
        })
    )
    
    (ok true))
)

;; Transfer artifact ownership
(define-public (transfer-artifact-ownership (artifact-id uint) (new-owner principal))
    (let (
        (artifact-info (unwrap! (map-get? cultural-artifacts artifact-id) ERR_ARTIFACT_NOT_FOUND))
        (new-institution-info (unwrap! (map-get? cultural-institutions new-owner) ERR_RECORD_NOT_FOUND))
        (current-institution-info (unwrap! (map-get? cultural-institutions (get institution-address artifact-info)) ERR_RECORD_NOT_FOUND))
        (current-height block-height)
        (transfer-fee (calculate-platform-fee (get acquisition-price artifact-info)))
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (is-eq tx-sender (get institution-address artifact-info)) ERR_ACCESS_DENIED)
    
    ;; Process platform fee for transfer
    (try! (stx-transfer? transfer-fee tx-sender PLATFORM_ADMIN))
    
    ;; Update verification pool
    (var-set verification-pool-balance (+ (var-get verification-pool-balance) transfer-fee))
    
    ;; Update artifact ownership
    (map-set cultural-artifacts artifact-id
        (merge artifact-info { 
            institution-address: new-owner,
            discovery-height: current-height
        })
    )
    
    ;; Update artifact counts for both institutions
    (map-set cultural-institutions tx-sender
        (merge current-institution-info { 
            artifact-count: (- (get artifact-count current-institution-info) u1),
            last-update-height: current-height
        })
    )
    
    (map-set cultural-institutions new-owner
        (merge new-institution-info { 
            artifact-count: (+ (get artifact-count new-institution-info) u1),
            last-update-height: current-height
        })
    )
    
    (ok true))
)

;; End verification
(define-public (end-verification)
    (let (
        (verifier-info (unwrap! (map-get? verifiers tx-sender) ERR_UNAUTHORIZED_VERIFIER))
        (artifact-info (unwrap! (map-get? cultural-artifacts (get verified-artifact-id verifier-info)) ERR_ARTIFACT_NOT_FOUND))
        (remaining-blocks (- (get verification-end-height verifier-info) block-height))
        (remaining-years (/ remaining-blocks BLOCKS_PER_YEAR))
        (refund-amount (* remaining-years (get annual-fee verifier-info)))
        (platform-fee (calculate-platform-fee refund-amount))
        (institution-refund (- refund-amount platform-fee))
    )
    (asserts! (not (var-get platform-paused)) ERR_ACCESS_DENIED)
    (asserts! (get has-active-verification verifier-info) ERR_NO_VERIFICATION)
    
    ;; Process refund if applicable
    (when (> institution-refund u0)
        (try! (stx-transfer? institution-refund (get institution-address artifact-info) tx-sender))
        
        ;; Update verification pool balance
        (var-set verification-pool-balance (- (var-get verification-pool-balance) platform-fee))
    )
    
    ;; Reset verifier active verification status
    (map-set verifiers tx-sender
        (merge verifier-info { 
            has-active-verification: false,
            verified-artifact-id: u0,
            verification-scope: "",
            annual-fee: u0,
            verification-start-height: u0,
            verification-end-height: u0,
            last-verification-height: block-height
        })
    )
    
    ;; Update artifact verification count
    (map-set cultural-artifacts (get verified-artifact-id verifier-info)
        (merge artifact-info { active-verification-count: (- (get active-verification-count artifact-info) u1) })
    )
    
    (ok true))
)

;; Platform pause/unpause
(define-public (set-platform-status (new-status bool))
    (begin
        (asserts! (check-admin-access) ERR_ADMIN_ONLY)
        (var-set platform-paused new-status)
        (ok true))
)

;; Emergency shutdown
(define-public (emergency-shutdown)
    (begin
        (asserts! (check-admin-access) ERR_ADMIN_ONLY)
        (var-set platform-paused true)
        (ok true))
)