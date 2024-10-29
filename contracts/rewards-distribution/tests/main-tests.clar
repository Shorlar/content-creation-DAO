;; rewards-distribution/tests/main-tests.clar

;; Import the main contract
(impl-trait .rewards-distribution.rewards-distribution-trait)

;; Test constants and mock data
(define-constant CONTRIBUTOR_1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant CONTRIBUTOR_2 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(define-constant CONTRIBUTOR_3 'ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21XCP)
(define-constant CONTENT_1 "First Article")
(define-constant CONTENT_2 "Video Tutorial")
(define-constant REWARD_AMOUNT_1 u1000)
(define-constant REWARD_AMOUNT_2 u500)

;; Test cases for recording contributions
(define-public (test-record-contribution)
    (begin
        ;; Test 1: Record basic contribution
        (let ((record-result (contract-call? .rewards-distribution record-contribution 
                            CONTRIBUTOR_1 CONTENT_1 REWARD_AMOUNT_1)))
            (asserts! (is-ok record-result) (err "Failed to record contribution"))
            
            ;; Verify contribution was recorded
            (let ((contribution (contract-call? .rewards-distribution get-contribution 
                               CONTRIBUTOR_1 CONTENT_1)))
                (asserts! (is-some contribution) (err "Contribution not found"))
                (asserts! (is-eq (get reward-amount (unwrap-panic contribution)) REWARD_AMOUNT_1) 
                    (err "Incorrect reward amount recorded"))
            )
        )

        ;; Test 2: Record multiple contributions for same content
        (let ((second-contribution (contract-call? .rewards-distribution record-contribution 
                                  CONTRIBUTOR_1 CONTENT_1 REWARD_AMOUNT_2)))
            (asserts! (is-ok second-contribution) (err "Failed to record second contribution"))
            
            ;; Verify cumulative reward amount
            (let ((updated-contribution (contract-call? .rewards-distribution get-contribution 
                                      CONTRIBUTOR_1 CONTENT_1)))
                (asserts! (is-some updated-contribution) (err "Updated contribution not found"))
                (asserts! (is-eq (get reward-amount (unwrap-panic updated-contribution)) 
                    (+ REWARD_AMOUNT_1 REWARD_AMOUNT_2)) 
                    (err "Incorrect cumulative reward amount"))
            )
        )

        ;; Test 3: Record contribution with zero amount
        (let ((zero-contribution (contract-call? .rewards-distribution record-contribution 
                                CONTRIBUTOR_2 CONTENT_2 u0)))
            (asserts! (is-err zero-contribution) 
                (err "Should fail when recording zero reward amount"))
        )

        (ok true)
    )
)

;; Test cases for multiple contributors
(define-public (test-multiple-contributors)
    (begin
        ;; Setup: Record multiple contributions
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 REWARD_AMOUNT_1))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_2 CONTENT_1 REWARD_AMOUNT_2))
        
        ;; Test 1: Verify individual contributions
        (let ((contribution1 (contract-call? .rewards-distribution get-contribution 
                            CONTRIBUTOR_1 CONTENT_1))
              (contribution2 (contract-call? .rewards-distribution get-contribution 
                            CONTRIBUTOR_2 CONTENT_1)))
            
            (asserts! (is-some contribution1) (err "First contribution not found"))
            (asserts! (is-some contribution2) (err "Second contribution not found"))
            (asserts! (is-eq (get reward-amount (unwrap-panic contribution1)) REWARD_AMOUNT_1) 
                (err "Incorrect reward amount for first contributor"))
            (asserts! (is-eq (get reward-amount (unwrap-panic contribution2)) REWARD_AMOUNT_2) 
                (err "Incorrect reward amount for second contributor"))
        )

        ;; Test 2: Update existing contributor's reward
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 u200))
        (let ((updated-contribution (contract-call? .rewards-distribution get-contribution 
                                   CONTRIBUTOR_1 CONTENT_1)))
            (asserts! (is-eq (get reward-amount (unwrap-panic updated-contribution)) 
                (+ REWARD_AMOUNT_1 u200)) 
                (err "Incorrect updated reward amount"))
        )

        (ok true)
    )
)

;; Test cases for reward distribution
(define-public (test-distribute-rewards)
    (begin
        ;; Setup: Record various contributions
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 REWARD_AMOUNT_1))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_2 CONTENT_2 REWARD_AMOUNT_2))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_3 CONTENT_1 u750))

        ;; Test 1: Basic reward distribution
        (let ((distribution-result (contract-call? .rewards-distribution distribute-rewards)))
            (asserts! (is-ok distribution-result) (err "Failed to distribute rewards"))
        )

        ;; Test 2: Verify rewards were cleared after distribution
        (let ((contribution1 (contract-call? .rewards-distribution get-contribution 
                            CONTRIBUTOR_1 CONTENT_1))
              (contribution2 (contract-call? .rewards-distribution get-contribution 
                            CONTRIBUTOR_2 CONTENT_2)))
            
            (asserts! (is-none contribution1) 
                (err "Contribution should be cleared after distribution"))
            (asserts! (is-none contribution2) 
                (err "Contribution should be cleared after distribution"))
        )

        ;; Test 3: Distribute with no recorded contributions
        (let ((empty-distribution (contract-call? .rewards-distribution distribute-rewards)))
            (asserts! (is-ok empty-distribution) 
                (err "Should handle distribution with no contributions"))
        )

        (ok true)
    )
)

;; Test cases for contribution queries
(define-public (test-get-contribution)
    (begin
        ;; Test 1: Get non-existent contribution
        (let ((non-existent (contract-call? .rewards-distribution get-contribution 
                           CONTRIBUTOR_1 "Non-existent")))
            (asserts! (is-none non-existent) (err "Should return none for non-existent contribution"))
        )

        ;; Test 2: Get existing contribution
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 REWARD_AMOUNT_1))
        (let ((contribution (contract-call? .rewards-distribution get-contribution 
                           CONTRIBUTOR_1 CONTENT_1)))
            (asserts! (is-some contribution) (err "Should find recorded contribution"))
            (let ((unwrapped-contribution (unwrap-panic contribution)))
                (asserts! (is-eq (get contributor unwrapped-contribution) CONTRIBUTOR_1) 
                    (err "Incorrect contributor"))
                (asserts! (is-eq (get content-title unwrapped-contribution) CONTENT_1) 
                    (err "Incorrect content title"))
                (asserts! (is-eq (get reward-amount unwrapped-contribution) REWARD_AMOUNT_1) 
                    (err "Incorrect reward amount"))
            )
        )

        (ok true)
    )
)

;; Integration tests
(define-public (test-full-reward-workflow)
    (begin
        ;; 1. Record multiple contributions
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 REWARD_AMOUNT_1))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_2 CONTENT_1 REWARD_AMOUNT_2))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_2 u300))
        
        ;; 2. Update existing contributions
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 u200))
        
        ;; 3. Distribute rewards
        (try! (contract-call? .rewards-distribution distribute-rewards))
        
        ;; 4. Verify state after distribution
        (let ((contribution1 (contract-call? .rewards-distribution get-contribution 
                            CONTRIBUTOR_1 CONTENT_1))
              (contribution2 (contract-call? .rewards-distribution get-contribution 
                            CONTRIBUTOR_2 CONTENT_1)))
            
            (asserts! (is-none contribution1) 
                (err "Contribution should be cleared after distribution"))
            (asserts! (is-none contribution2) 
                (err "Contribution should be cleared after distribution"))
        )

        ;; 5. Record new contributions after distribution
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_3 CONTENT_2 u500))

        (ok true)
    )
)

;; Test edge cases
(define-public (test-edge-cases)
    (begin
        ;; Test 1: Very large reward amounts
        (let ((large-reward (contract-call? .rewards-distribution record-contribution 
                           CONTRIBUTOR_1 CONTENT_1 u1000000000)))
            (asserts! (is-ok large-reward) (err "Should handle large reward amounts"))
        )

        ;; Test 2: Multiple contributions to same content
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 u100))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 u100))
        (try! (contract-call? .rewards-distribution record-contribution 
               CONTRIBUTOR_1 CONTENT_1 u100))
        
        ;; Test 3: Empty content title
        (let ((empty-content (contract-call? .rewards-distribution record-contribution 
                            CONTRIBUTOR_1 "" REWARD_AMOUNT_1)))
            (asserts! (is-err empty-content) 
                (err "Should fail with empty content title"))
        )

        (ok true)
    )
)

;; Run all tests
(define-public (run-all-tests)
    (begin
        (print "Starting rewards distribution tests...")
        (try! (test-record-contribution))
        (try! (test-multiple-contributors))
        (try! (test-distribute-rewards))
        (try! (test-get-contribution))
        (try! (test-full-reward-workflow))
        (try! (test-edge-cases))
        (ok "All rewards distribution tests completed successfully!")
    )
)