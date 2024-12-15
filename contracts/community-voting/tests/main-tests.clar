;; community-voting/tests/main-tests.clar

;; Import the main contract
(impl-trait .community-voting.content-proposal-trait)

;; Test utilities and mock data
(define-constant PROPOSAL_TITLE "Test Proposal")
(define-constant TEST_ADDRESS 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant ADMIN_ADDRESS 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

(define-map test-proposals {id: uint} {title: string, votes: uint})

;; Test cases
(define-public (test-submit-proposal)
    (begin
        ;; Test 1: Submit a new proposal
        (let ((result (contract-call? .community-voting submit-proposal PROPOSAL_TITLE)))
            (asserts! (is-ok result) (err "Failed to submit proposal"))
            (asserts! (is-eq (unwrap-panic result) u1) (err "Incorrect proposal ID"))
        )

        ;; Test 2: Verify proposal details
        (let ((proposal (contract-call? .community-voting get-proposal u1)))
            (asserts! (is-some proposal) (err "Proposal not found"))
            (asserts! (is-eq (get title (unwrap-panic proposal)) PROPOSAL_TITLE) 
                (err "Incorrect proposal title"))
            (asserts! (is-eq (get votes (unwrap-panic proposal)) u0) 
                (err "Initial votes should be 0"))
        )

        ;; Test 3: Submit multiple proposals
        (let ((result2 (contract-call? .community-voting submit-proposal "Second Proposal")))
            (asserts! (is-ok result2) (err "Failed to submit second proposal"))
            (asserts! (is-eq (unwrap-panic result2) u2) (err "Incorrect second proposal ID"))
        )

        (ok true)
    )
)

(define-public (test-vote-on-proposal)
    (begin
        ;; Setup: Submit a test proposal
        (try! (contract-call? .community-voting submit-proposal PROPOSAL_TITLE))

        ;; Test 1: Valid vote
        (let ((vote-result (contract-call? .community-voting vote-on-proposal u1 u5)))
            (asserts! (is-ok vote-result) (err "Failed to vote on proposal"))
            
            ;; Verify vote count
            (let ((proposal (contract-call? .community-voting get-proposal u1)))
                (asserts! (is-some proposal) (err "Proposal not found after voting"))
                (asserts! (is-eq (get votes (unwrap-panic proposal)) u5) 
                    (err "Vote count not updated correctly"))
            )
        )

        ;; Test 2: Vote on non-existent proposal
        (let ((invalid-vote (contract-call? .community-voting vote-on-proposal u999 u1)))
            (asserts! (is-err invalid-vote) (err "Should fail when voting on non-existent proposal"))
            (asserts! (is-eq (unwrap-err invalid-vote) u404) 
                (err "Incorrect error code for non-existent proposal"))
        )

        ;; Test 3: Multiple votes on same proposal
        (let ((second-vote (contract-call? .community-voting vote-on-proposal u1 u3)))
            (asserts! (is-ok second-vote) (err "Failed to submit second vote"))
            
            ;; Verify cumulative votes
            (let ((proposal (contract-call? .community-voting get-proposal u1)))
                (asserts! (is-some proposal) (err "Proposal not found after second vote"))
                (asserts! (is-eq (get votes (unwrap-panic proposal)) u8) 
                    (err "Cumulative votes not calculated correctly"))
            )
        )

        (ok true)
    )
)

(define-public (test-allocate-funds)
    (begin
        ;; Setup: Create multiple proposals with votes
        (try! (contract-call? .community-voting submit-proposal "Proposal 1"))
        (try! (contract-call? .community-voting submit-proposal "Proposal 2"))
        (try! (contract-call? .community-voting submit-proposal "Proposal 3"))
        
        (try! (contract-call? .community-voting vote-on-proposal u1 u10))
        (try! (contract-call? .community-voting vote-on-proposal u2 u5))
        (try! (contract-call? .community-voting vote-on-proposal u3 u15))

        ;; Test 1: Allocate funds to top proposals
        (let ((proposal-ids (list u1 u2 u3))
              (allocation-result (contract-call? .community-voting allocate-funds proposal-ids)))
            (asserts! (is-ok allocation-result) (err "Failed to allocate funds"))
        )

        ;; Test 2: Try to allocate funds with empty list
        (let ((empty-allocation (contract-call? .community-voting allocate-funds (list))))
            (asserts! (is-err empty-allocation) (err "Should fail with empty proposal list"))
        )

        ;; Test 3: Try to allocate funds with invalid proposal IDs
        (let ((invalid-proposals (list u999 u1000))
              (invalid-allocation (contract-call? .community-voting allocate-funds invalid-proposals)))
            (asserts! (is-err invalid-allocation) (err "Should fail with invalid proposal IDs"))
        )

        (ok true)
    )
)

;; Test helper functions
(define-public (test-get-proposal-count)
    (begin
        ;; Setup: Submit multiple proposals
        (try! (contract-call? .community-voting submit-proposal "Test 1"))
        (try! (contract-call? .community-voting submit-proposal "Test 2"))
        
        ;; Test: Verify proposal count
        (let ((count (contract-call? .community-voting get-proposal-count)))
            (asserts! (is-eq count u2) (err "Incorrect proposal count"))
        )

        (ok true)
    )
)

;; Integration tests
(define-public (test-full-voting-workflow)
    (begin
        ;; 1. Submit proposals
        (try! (contract-call? .community-voting submit-proposal "Proposal A"))
        (try! (contract-call? .community-voting submit-proposal "Proposal B"))
        (try! (contract-call? .community-voting submit-proposal "Proposal C"))

        ;; 2. Cast votes
        (try! (contract-call? .community-voting vote-on-proposal u1 u10))
        (try! (contract-call? .community-voting vote-on-proposal u2 u20))
        (try! (contract-call? .community-voting vote-on-proposal u3 u15))

        ;; 3. Additional votes from different addresses
        (as-contract (try! (contract-call? .community-voting vote-on-proposal u1 u5)))
        (as-contract (try! (contract-call? .community-voting vote-on-proposal u2 u10)))

        ;; 4. Verify final vote tallies
        (let ((proposal1 (contract-call? .community-voting get-proposal u1))
              (proposal2 (contract-call? .community-voting get-proposal u2))
              (proposal3 (contract-call? .community-voting get-proposal u3)))
            
            (asserts! (is-eq (get votes (unwrap-panic proposal1)) u15) 
                (err "Incorrect final votes for proposal 1"))
            (asserts! (is-eq (get votes (unwrap-panic proposal2)) u30) 
                (err "Incorrect final votes for proposal 2"))
            (asserts! (is-eq (get votes (unwrap-panic proposal3)) u15) 
                (err "Incorrect final votes for proposal 3"))
        )

        ;; 5. Allocate funds based on votes
        (let ((proposal-ids (list u1 u2 u3)))
            (try! (contract-call? .community-voting allocate-funds proposal-ids))
        )

        (ok true)
    )
)

;; Run all tests
(define-public (run-all-tests)
    (begin
        (try! (test-submit-proposal))
        (try! (test-vote-on-proposal))
        (try! (test-allocate-funds))
        (try! (test-get-proposal-count))
        (try! (test-full-voting-workflow))
        (ok "All tests passed successfully!")
    )
)