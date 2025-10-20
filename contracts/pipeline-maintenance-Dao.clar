(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1))
(define-constant ERR_INVALID_AMOUNT (err u2))
(define-constant ERR_REPORT_NOT_FOUND (err u3))
(define-constant ERR_ALREADY_VOTED (err u4))
(define-constant ERR_VOTING_CLOSED (err u5))
(define-constant ERR_NOT_APPROVED (err u6))
(define-constant ERR_ALREADY_PAID (err u7))
(define-constant ERR_INSUFFICIENT_FUNDS (err u8))
(define-constant ERR_INVALID_STATUS (err u9))
(define-constant ERR_NOT_CONTRACTOR (err u10))
(define-constant ERR_EMERGENCY_ONLY (err u11))
(define-constant ERR_NOT_EMERGENCY (err u12))

(define-constant VOTING_PERIOD u144)
(define-constant EMERGENCY_VOTING_PERIOD u24)
(define-constant MIN_APPROVAL_THRESHOLD u66)
(define-constant EMERGENCY_APPROVAL_THRESHOLD u80)
(define-constant MAX_REPORT_AMOUNT u10000000)
(define-constant MAX_EMERGENCY_AMOUNT u5000000)

(define-data-var next-report-id uint u1)
(define-data-var total-treasury uint u0)
(define-data-var dao-members-count uint u0)
(define-data-var total-emergency-reports uint u0)

(define-map dao-members principal bool)
(define-map field-workers principal bool)
(define-map contractors principal bool)

(define-map maintenance-reports
  uint
  {
    reporter: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    location: (string-ascii 128),
    estimated-cost: uint,
    contractor: (optional principal),
    status: (string-ascii 16),
    created-at: uint,
    voting-deadline: uint,
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    payment-completed: bool,
    is-emergency: bool
  }
)

(define-map report-votes
  { report-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

(define-map member-voting-power principal uint)

(define-public (initialize-dao)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set dao-members CONTRACT_OWNER true)
    (map-set member-voting-power CONTRACT_OWNER u100)
    (var-set dao-members-count u1)
    (ok true)
  )
)

(define-public (add-dao-member (member principal) (voting-power uint))
  (begin
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (<= voting-power u100) ERR_INVALID_AMOUNT)
    (map-set dao-members member true)
    (map-set member-voting-power member voting-power)
    (var-set dao-members-count (+ (var-get dao-members-count) u1))
    (ok true)
  )
)

(define-public (add-field-worker (worker principal))
  (begin
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (map-set field-workers worker true)
    (ok true)
  )
)

(define-public (add-contractor (contractor principal))
  (begin
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (map-set contractors contractor true)
    (ok true)
  )
)

(define-public (fund-treasury (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-treasury (+ (var-get total-treasury) amount))
    (ok amount)
  )
)

(define-public (submit-maintenance-report 
  (title (string-ascii 64))
  (description (string-ascii 256))
  (location (string-ascii 128))
  (estimated-cost uint))
  (let
    (
      (report-id (var-get next-report-id))
      (current-block u1)
    )
    (asserts! (default-to false (map-get? field-workers tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (<= estimated-cost MAX_REPORT_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (> estimated-cost u0) ERR_INVALID_AMOUNT)
    
    (map-set maintenance-reports report-id
      {
        reporter: tx-sender,
        title: title,
        description: description,
        location: location,
        estimated-cost: estimated-cost,
        contractor: none,
        status: "pending",
        created-at: current-block,
        voting-deadline: (+ current-block VOTING_PERIOD),
        votes-for: u0,
        votes-against: u0,
        total-voters: u0,
        payment-completed: false,
        is-emergency: false
      }
    )
    
    (var-set next-report-id (+ report-id u1))
    (ok report-id)
  )
)

(define-public (vote-on-report (report-id uint) (vote-for bool))
  (let
    (
      (report (unwrap! (map-get? maintenance-reports report-id) ERR_REPORT_NOT_FOUND))
      (voter-power (default-to u0 (map-get? member-voting-power tx-sender)))
      (current-block u1)
      (existing-vote (map-get? report-votes { report-id: report-id, voter: tx-sender }))
    )
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (<= current-block (get voting-deadline report)) ERR_VOTING_CLOSED)
    (asserts! (is-eq (get status report) "pending") ERR_INVALID_STATUS)
    
    (map-set report-votes { report-id: report-id, voter: tx-sender }
      { vote: vote-for, voted-at: current-block })
    
    (map-set maintenance-reports report-id
      (merge report
        {
          votes-for: (if vote-for (+ (get votes-for report) voter-power) (get votes-for report)),
          votes-against: (if vote-for (get votes-against report) (+ (get votes-against report) voter-power)),
          total-voters: (+ (get total-voters report) u1)
        }
      )
    )
    (ok true)
  )
)

(define-public (finalize-voting (report-id uint))
  (let
    (
      (report (unwrap! (map-get? maintenance-reports report-id) ERR_REPORT_NOT_FOUND))
      (current-block u1)
      (total-votes (+ (get votes-for report) (get votes-against report)))
      (approval-percentage (if (> total-votes u0) 
        (/ (* (get votes-for report) u100) total-votes) u0))
    )
    (asserts! (>= current-block (get voting-deadline report)) ERR_VOTING_CLOSED)
    (asserts! (is-eq (get status report) "pending") ERR_INVALID_STATUS)
    
    (if (>= approval-percentage MIN_APPROVAL_THRESHOLD)
      (map-set maintenance-reports report-id (merge report { status: "approved" }))
      (map-set maintenance-reports report-id (merge report { status: "rejected" }))
    )
    (ok approval-percentage)
  )
)

(define-public (assign-contractor (report-id uint) (contractor principal))
  (let
    (
      (report (unwrap! (map-get? maintenance-reports report-id) ERR_REPORT_NOT_FOUND))
    )
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (default-to false (map-get? contractors contractor)) ERR_NOT_CONTRACTOR)
    (asserts! (is-eq (get status report) "approved") ERR_NOT_APPROVED)
    
    (map-set maintenance-reports report-id
      (merge report { contractor: (some contractor), status: "assigned" }))
    (ok true)
  )
)

(define-public (complete-work (report-id uint))
  (let
    (
      (report (unwrap! (map-get? maintenance-reports report-id) ERR_REPORT_NOT_FOUND))
      (contractor (unwrap! (get contractor report) ERR_NOT_CONTRACTOR))
    )
    (asserts! (is-eq tx-sender contractor) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status report) "assigned") ERR_INVALID_STATUS)
    
    (map-set maintenance-reports report-id
      (merge report { status: "completed" }))
    (ok true)
  )
)

(define-public (release-payment (report-id uint))
  (let
    (
      (report (unwrap! (map-get? maintenance-reports report-id) ERR_REPORT_NOT_FOUND))
      (contractor (unwrap! (get contractor report) ERR_NOT_CONTRACTOR))
      (payment-amount (get estimated-cost report))
    )
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status report) "completed") ERR_INVALID_STATUS)
    (asserts! (not (get payment-completed report)) ERR_ALREADY_PAID)
    (asserts! (>= (var-get total-treasury) payment-amount) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? payment-amount tx-sender contractor)))
    (var-set total-treasury (- (var-get total-treasury) payment-amount))
    
    (map-set maintenance-reports report-id
      (merge report { payment-completed: true, status: "paid" }))
    (ok payment-amount)
  )
)

(define-public (submit-emergency-report
  (title (string-ascii 64))
  (description (string-ascii 256))
  (location (string-ascii 128))
  (estimated-cost uint))
  (let
    (
      (report-id (var-get next-report-id))
      (current-block u1)
    )
    (asserts! (default-to false (map-get? field-workers tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (<= estimated-cost MAX_EMERGENCY_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (> estimated-cost u0) ERR_INVALID_AMOUNT)
    
    (map-set maintenance-reports report-id
      {
        reporter: tx-sender,
        title: title,
        description: description,
        location: location,
        estimated-cost: estimated-cost,
        contractor: none,
        status: "pending",
        created-at: current-block,
        voting-deadline: (+ current-block EMERGENCY_VOTING_PERIOD),
        votes-for: u0,
        votes-against: u0,
        total-voters: u0,
        payment-completed: false,
        is-emergency: true
      }
    )
    
    (var-set next-report-id (+ report-id u1))
    (var-set total-emergency-reports (+ (var-get total-emergency-reports) u1))
    (ok report-id)
  )
)

(define-public (expedite-emergency-approval (report-id uint))
  (let
    (
      (report (unwrap! (map-get? maintenance-reports report-id) ERR_REPORT_NOT_FOUND))
      (current-block u1)
      (total-votes (+ (get votes-for report) (get votes-against report)))
      (approval-percentage (if (> total-votes u0) 
        (/ (* (get votes-for report) u100) total-votes) u0))
    )
    (asserts! (default-to false (map-get? dao-members tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-emergency report) ERR_NOT_EMERGENCY)
    (asserts! (is-eq (get status report) "pending") ERR_INVALID_STATUS)
    (asserts! (>= approval-percentage EMERGENCY_APPROVAL_THRESHOLD) ERR_NOT_APPROVED)
    
    (map-set maintenance-reports report-id 
      (merge report { status: "approved" }))
    (ok approval-percentage)
  )
)

(define-read-only (get-report (report-id uint))
  (map-get? maintenance-reports report-id)
)

(define-read-only (get-vote (report-id uint) (voter principal))
  (map-get? report-votes { report-id: report-id, voter: voter })
)

(define-read-only (get-treasury-balance)
  (var-get total-treasury)
)

(define-read-only (get-next-report-id)
  (var-get next-report-id)
)

(define-read-only (is-dao-member (member principal))
  (default-to false (map-get? dao-members member))
)

(define-read-only (is-field-worker (worker principal))
  (default-to false (map-get? field-workers worker))
)

(define-read-only (is-contractor (contractor principal))
  (default-to false (map-get? contractors contractor))
)

(define-read-only (get-voting-power (member principal))
  (default-to u0 (map-get? member-voting-power member))
)

(define-read-only (get-dao-stats)
  {
    members-count: (var-get dao-members-count),
    treasury-balance: (var-get total-treasury),
    total-reports: (- (var-get next-report-id) u1)
  }
)

(define-read-only (is-emergency-report (report-id uint))
  (match (map-get? maintenance-reports report-id)
    report (get is-emergency report)
    false
  )
)

(define-read-only (get-emergency-stats)
  {
    total-emergency-reports: (var-get total-emergency-reports),
    emergency-voting-period: EMERGENCY_VOTING_PERIOD,
    emergency-threshold: EMERGENCY_APPROVAL_THRESHOLD,
    max-emergency-amount: MAX_EMERGENCY_AMOUNT
  }
)

(define-read-only (can-expedite-emergency (report-id uint))
  (match (map-get? maintenance-reports report-id)
    report
      (let
        (
          (total-votes (+ (get votes-for report) (get votes-against report)))
          (approval-percentage (if (> total-votes u0) 
            (/ (* (get votes-for report) u100) total-votes) u0))
        )
        (and
          (get is-emergency report)
          (is-eq (get status report) "pending")
          (>= approval-percentage EMERGENCY_APPROVAL_THRESHOLD)
        )
      )
    false
  )
)
