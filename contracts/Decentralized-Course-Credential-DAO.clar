

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-MEMBER (err u101))
(define-constant ERR-NOT-MEMBER (err u102))
(define-constant ERR-COURSE-EXISTS (err u103))
(define-constant ERR-INVALID-VOTE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-VOTING-CLOSED (err u106))
(define-constant ERR-COURSE-NOT-FOUND (err u107))
(define-constant ERR-NOT-ENOUGH-STAKE (err u108))

(define-data-var dao-owner principal tx-sender)
(define-data-var min-stake uint u1000)
(define-data-var voting-period uint u144)
(define-data-var next-course-id uint u1)
(define-data-var next-credential-id uint u1)

(define-map dao-members 
    principal 
    {stake: uint, reputation: uint}
)

(define-map courses 
    uint 
    {
        creator: principal,
        name: (string-ascii 50),
        content-uri: (string-ascii 256),
        status: (string-ascii 20),
        votes-for: uint,
        votes-against: uint,
        voting-ends-at: uint,
        approved: bool
    }
)

(define-map course-votes
    {course-id: uint, voter: principal}
    {vote: bool}
)

(define-map credentials
    uint
    {
        recipient: principal,
        course-id: uint,
        timestamp: uint
    }
)

(define-non-fungible-token credential uint)

(define-public (initialize-dao (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (var-set dao-owner new-owner)
        (ok true)))

(define-public (join-dao (stake uint))
    (begin
        (asserts! (>= stake (var-get min-stake)) ERR-NOT-ENOUGH-STAKE)
        (asserts! (is-none (map-get? dao-members tx-sender)) ERR-ALREADY-MEMBER)
        (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
        (map-set dao-members tx-sender {stake: stake, reputation: u100})
        (ok true)))

(define-public (submit-course (name (string-ascii 50)) (content-uri (string-ascii 256)))
    (let ((course-id (var-get next-course-id)))
        (asserts! (is-some (map-get? dao-members tx-sender)) ERR-NOT-MEMBER)
        (map-set courses course-id 
            {
                creator: tx-sender,
                name: name,
                content-uri: content-uri,
                status: "voting",
                votes-for: u0,
                votes-against: u0,
                voting-ends-at: (+ burn-block-height (var-get voting-period)),
                approved: false
            })
        (var-set next-course-id (+ course-id u1))
        (ok course-id)))

(define-public (vote-on-course (course-id uint) (vote bool))
    (let ((course (unwrap! (map-get? courses course-id) ERR-COURSE-NOT-FOUND))
          (member (unwrap! (map-get? dao-members tx-sender) ERR-NOT-MEMBER)))
        (asserts! (< stacks-block-height (get voting-ends-at course)) ERR-VOTING-CLOSED)
        (asserts! (is-none (map-get? course-votes {course-id: course-id, voter: tx-sender})) ERR-ALREADY-VOTED)
        (map-set course-votes {course-id: course-id, voter: tx-sender} {vote: vote})
        (if vote
            (map-set courses course-id (merge course {votes-for: (+ (get votes-for course) u1)}))
            (map-set courses course-id (merge course {votes-against: (+ (get votes-against course) u1)})))
        (ok true)))

(define-public (finalize-course (course-id uint))
    (let ((course (unwrap! (map-get? courses course-id) ERR-COURSE-NOT-FOUND)))
        (asserts! (>= stacks-block-height (get voting-ends-at course)) ERR-VOTING-CLOSED)
        (map-set courses course-id 
            (merge course 
                {
                    status: "completed",
                    approved: (> (get votes-for course) (get votes-against course))
                }))
        (ok true)))

(define-public (mint-credential (course-id uint) (recipient principal))
    (let ((course (unwrap! (map-get? courses course-id) ERR-COURSE-NOT-FOUND))
          (credential-id (var-get next-credential-id)))
        (asserts! (get approved course) ERR-NOT-AUTHORIZED)
        (try! (nft-mint? credential credential-id recipient))
        (map-set credentials credential-id 
            {
                recipient: recipient,
                course-id: course-id,
                timestamp: stacks-block-height
            })
        (var-set next-credential-id (+ credential-id u1))
        (ok credential-id)))

(define-read-only (get-course (course-id uint))
    (ok (map-get? courses course-id)))

(define-read-only (get-member (address principal))
    (ok (map-get? dao-members address)))

(define-read-only (get-credential (credential-id uint))
    (ok (map-get? credentials credential-id)))

(define-read-only (get-last-token-id)
    (ok (- (var-get next-credential-id) u1)))

(define-read-only (get-token-uri (token-id uint))
    (ok none))

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? credential token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? credential token-id sender recipient)))
