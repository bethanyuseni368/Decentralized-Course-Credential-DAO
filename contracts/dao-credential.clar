;; Decentralized Course Credential DAO with Achievement Badge System

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-MEMBER (err u101))
(define-constant ERR-NOT-MEMBER (err u102))
(define-constant ERR-COURSE-EXISTS (err u103))
(define-constant ERR-INVALID-VOTE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-VOTING-CLOSED (err u106))
(define-constant ERR-COURSE-NOT-FOUND (err u107))
(define-constant ERR-NOT-ENOUGH-STAKE (err u108))
(define-constant ERR-COURSE-NOT-APPROVED (err u109))
(define-constant ERR-ALREADY-RATED (err u110))
(define-constant ERR-INVALID-RATING (err u111))
(define-constant ERR-NOT-ENROLLED (err u112))
(define-constant ERR-BADGE-NOT-FOUND (err u113))
(define-constant ERR-BADGE-ALREADY-EARNED (err u114))
(define-constant ERR-INSUFFICIENT-ACTIVITY (err u115))
(define-constant ERR-INVALID-BADGE-TYPE (err u116))

;; DAO configuration variables
(define-data-var dao-owner principal tx-sender)
(define-data-var min-stake uint u1000)
(define-data-var voting-period uint u144)
(define-data-var next-course-id uint u1)
(define-data-var next-credential-id uint u1)
(define-data-var next-badge-id uint u1)

;; Core DAO data structures
(define-map dao-members 
    principal 
    {
        stake: uint, 
        reputation: uint,
        join-date: uint,
        courses-completed: uint,
        badges-earned: uint
    }
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

(define-map course-ratings
    {course-id: uint, rater: principal}
    {rating: uint, timestamp: uint}
)

(define-map course-rating-stats
    uint
    {
        total-ratings: uint,
        sum-ratings: uint
    }
)

(define-map course-enrollments
    {course-id: uint, student: principal}
    {enrolled: bool, timestamp: uint}
)

;; Achievement Badge System Data Structures
(define-map badge-definitions
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        badge-type: (string-ascii 20),
        requirement-value: uint,
        icon-uri: (string-ascii 256),
        active: bool
    }
)

(define-map user-badges
    {user: principal, badge-id: uint}
    {
        earned-date: uint,
        verified: bool
    }
)

(define-map badge-leaderboard
    uint
    {
        holder: principal,
        earned-date: uint,
        rank: uint
    }
)

;; NFT definition
(define-non-fungible-token credential uint)

;; Initialize DAO
(define-public (initialize-dao (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (var-set dao-owner new-owner)
        (try! (setup-default-badges))
        (ok true)))

;; Core DAO Functions
(define-public (join-dao (stake uint))
    (begin
        (asserts! (>= stake (var-get min-stake)) ERR-NOT-ENOUGH-STAKE)
        (asserts! (is-none (map-get? dao-members tx-sender)) ERR-ALREADY-MEMBER)
        (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
        (map-set dao-members tx-sender {
            stake: stake, 
            reputation: u100,
            join-date: stacks-block-height,
            courses-completed: u0,
            badges-earned: u0
        })
        ;; Check for "New Member" badge
        (try! (check-and-award-badge tx-sender u1))
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
                voting-ends-at: (+ stacks-block-height (var-get voting-period)),
                approved: false
            })
        (var-set next-course-id (+ course-id u1))
        ;; Check for course creation badges
        (try! (check-and-award-badge tx-sender u2))
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
        ;; Check for voting participation badges
        (try! (check-and-award-badge tx-sender u3))
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
          (credential-id (var-get next-credential-id))
          (member (unwrap! (map-get? dao-members recipient) ERR-NOT-MEMBER)))
        (asserts! (get approved course) ERR-COURSE-NOT-APPROVED)
        (asserts! (is-some (map-get? course-enrollments {course-id: course-id, student: recipient})) ERR-NOT-ENROLLED)
        (try! (nft-mint? credential credential-id recipient))
        (map-set credentials credential-id 
            {
                recipient: recipient,
                course-id: course-id,
                timestamp: stacks-block-height
            })
        ;; Update member's course completion count
        (map-set dao-members recipient 
            (merge member {courses-completed: (+ (get courses-completed member) u1)}))
        (var-set next-credential-id (+ credential-id u1))
        ;; Check for course completion badges
        (try! (check-and-award-badge recipient u4))
        (ok credential-id)))

;; Achievement Badge System Functions
(define-private (setup-default-badges)
    (begin
        ;; Badge 1: New Member
        (map-set badge-definitions u1 {
            name: "New Member",
            description: "Welcome to the DAO! Awarded for joining the community.",
            badge-type: "membership",
            requirement-value: u1,
            icon-uri: "ipfs://QmNewMemberBadge",
            active: true
        })
        ;; Badge 2: Course Creator
        (map-set badge-definitions u2 {
            name: "Course Creator", 
            description: "Awarded for submitting your first course for review.",
            badge-type: "creation",
            requirement-value: u1,
            icon-uri: "ipfs://QmCourseCreatorBadge",
            active: true
        })
        ;; Badge 3: Active Voter
        (map-set badge-definitions u3 {
            name: "Active Voter",
            description: "Participated in governance by voting on course proposals.",
            badge-type: "governance",
            requirement-value: u1,
            icon-uri: "ipfs://QmActiveVoterBadge",
            active: true
        })
        ;; Badge 4: Course Graduate
        (map-set badge-definitions u4 {
            name: "Course Graduate",
            description: "Successfully completed your first approved course.",
            badge-type: "achievement",
            requirement-value: u1,
            icon-uri: "ipfs://QmCourseGraduateBadge",
            active: true
        })
        ;; Badge 5: Scholar (5 courses completed)
        (map-set badge-definitions u5 {
            name: "Scholar",
            description: "Completed 5 approved courses - true dedication to learning!",
            badge-type: "achievement", 
            requirement-value: u5,
            icon-uri: "ipfs://QmScholarBadge",
            active: true
        })
        (var-set next-badge-id u6)
        (ok true)))

(define-public (create-custom-badge (name (string-ascii 50)) (description (string-ascii 200)) 
                                   (badge-type (string-ascii 20)) (requirement-value uint) 
                                   (icon-uri (string-ascii 256)))
    (let ((badge-id (var-get next-badge-id)))
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq badge-type "membership") 
                     (is-eq badge-type "creation")
                     (is-eq badge-type "governance") 
                     (is-eq badge-type "achievement")
                     (is-eq badge-type "special")) ERR-INVALID-BADGE-TYPE)
        (map-set badge-definitions badge-id {
            name: name,
            description: description,
            badge-type: badge-type,
            requirement-value: requirement-value,
            icon-uri: icon-uri,
            active: true
        })
        (var-set next-badge-id (+ badge-id u1))
        (ok badge-id)))

(define-private (check-and-award-badge (user principal) (badge-id uint))
    (let ((badge-def (unwrap! (map-get? badge-definitions badge-id) ERR-BADGE-NOT-FOUND))
          (member (unwrap! (map-get? dao-members user) ERR-NOT-MEMBER)))
        (if (and (get active badge-def)
                 (is-none (map-get? user-badges {user: user, badge-id: badge-id}))
                 (meets-badge-requirement user badge-id badge-def))
            (begin
                (map-set user-badges {user: user, badge-id: badge-id} {
                    earned-date: stacks-block-height,
                    verified: true
                })
                ;; Update badge count
                (map-set dao-members user 
                    (merge member {badges-earned: (+ (get badges-earned member) u1)}))
                (ok true))
            (ok false))))

(define-private (meets-badge-requirement (user principal) (badge-id uint) (badge-def {name: (string-ascii 50), description: (string-ascii 200), badge-type: (string-ascii 20), requirement-value: uint, icon-uri: (string-ascii 256), active: bool}))
    (let ((member (unwrap-panic (map-get? dao-members user))))
        (cond
            ;; New Member badge - just needs to be a member
            ((is-eq badge-id u1) true)
            ;; Course Creator badge - submitted at least 1 course  
            ((is-eq badge-id u2) true)
            ;; Active Voter badge - participated in voting
            ((is-eq badge-id u3) true)
            ;; Course Graduate badge - completed at least 1 course
            ((is-eq badge-id u4) (>= (get courses-completed member) u1))
            ;; Scholar badge - completed 5+ courses
            ((is-eq badge-id u5) (>= (get courses-completed member) u5))
            ;; Default case for custom badges based on courses completed
            (>= (get courses-completed member) (get requirement-value badge-def)))))

(define-public (award-special-badge (user principal) (badge-id uint))
    (let ((badge-def (unwrap! (map-get? badge-definitions badge-id) ERR-BADGE-NOT-FOUND))
          (member (unwrap! (map-get? dao-members user) ERR-NOT-MEMBER)))
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get badge-type badge-def) "special") ERR-INVALID-BADGE-TYPE)
        (asserts! (is-none (map-get? user-badges {user: user, badge-id: badge-id})) ERR-BADGE-ALREADY-EARNED)
        (map-set user-badges {user: user, badge-id: badge-id} {
            earned-date: stacks-block-height,
            verified: true
        })
        (map-set dao-members user 
            (merge member {badges-earned: (+ (get badges-earned member) u1)}))
        (ok true)))

;; Enhanced utility functions
(define-public (rate-course (course-id uint) (rating uint))
    (let ((course (unwrap! (map-get? courses course-id) ERR-COURSE-NOT-FOUND))
          (current-stats (default-to {total-ratings: u0, sum-ratings: u0} 
                         (map-get? course-rating-stats course-id))))
        (asserts! (is-some (map-get? dao-members tx-sender)) ERR-NOT-MEMBER)
        (asserts! (get approved course) ERR-COURSE-NOT-APPROVED)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
        (asserts! (is-none (map-get? course-ratings {course-id: course-id, rater: tx-sender})) ERR-ALREADY-RATED)
        (map-set course-ratings {course-id: course-id, rater: tx-sender} 
                 {rating: rating, timestamp: stacks-block-height})
        (map-set course-rating-stats course-id 
                 {total-ratings: (+ (get total-ratings current-stats) u1),
                  sum-ratings: (+ (get sum-ratings current-stats) rating)})
        (ok true)))

(define-public (enroll-in-course (course-id uint))
    (let ((course (unwrap! (map-get? courses course-id) ERR-COURSE-NOT-FOUND)))
        (asserts! (is-some (map-get? dao-members tx-sender)) ERR-NOT-MEMBER)
        (asserts! (is-none (map-get? course-enrollments {course-id: course-id, student: tx-sender})) ERR-ALREADY-MEMBER)
        (map-set course-enrollments {course-id: course-id, student: tx-sender}
                 {enrolled: true, timestamp: stacks-block-height})
        (ok true)))

;; Read-only functions
(define-read-only (get-course (course-id uint))
    (ok (map-get? courses course-id)))

(define-read-only (get-member (address principal))
    (ok (map-get? dao-members address)))

(define-read-only (get-credential (credential-id uint))
    (ok (map-get? credentials credential-id)))

(define-read-only (get-badge-definition (badge-id uint))
    (ok (map-get? badge-definitions badge-id)))

(define-read-only (get-user-badge (user principal) (badge-id uint))
    (ok (map-get? user-badges {user: user, badge-id: badge-id})))

(define-read-only (get-user-badges-count (user principal))
    (match (map-get? dao-members user)
        member (ok (get badges-earned member))
        (ok u0)))

(define-read-only (get-course-rating (course-id uint))
    (let ((stats (default-to {total-ratings: u0, sum-ratings: u0} 
                 (map-get? course-rating-stats course-id))))
        (if (> (get total-ratings stats) u0)
            (ok (some {
                average-rating: (/ (get sum-ratings stats) (get total-ratings stats)),
                total-ratings: (get total-ratings stats)
            }))
            (ok none))))

(define-read-only (is-enrolled (course-id uint) (student principal))
    (ok (is-some (map-get? course-enrollments {course-id: course-id, student: student}))))

;; NFT trait functions
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
