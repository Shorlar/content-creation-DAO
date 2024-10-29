;; curation-tokens/tests/main-tests.clar

;; Import the main contract
(impl-trait .curation-tokens.curation-token-trait)

;; Test constants and mock data
(define-constant TOKEN_OWNER 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant TOKEN_RECIPIENT 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(define-constant INITIAL_MINT_AMOUNT u1000)
(define-constant TRANSFER_AMOUNT u500)
(define-constant DISCOVERY_REWARD_AMOUNT u100)

;; Test cases for token minting
(define-public (test-mint-tokens)
    (begin
        ;; Test 1: Basic minting
        (let ((mint-result (contract-call? .curation-tokens mint-tokens TOKEN_OWNER INITIAL_MINT_AMOUNT)))
            (asserts! (is-ok mint-result) (err "Failed to mint tokens"))
            
            ;; Verify balance after minting
            (let ((balance (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
                (asserts! (is-eq balance INITIAL_MINT_AMOUNT) 
                    (err "Balance incorrect after minting"))
            )
        )

        ;; Test 2: Mint additional tokens
        (let ((second-mint (contract-call? .curation-tokens mint-tokens TOKEN_OWNER u500)))
            (asserts! (is-ok second-mint) (err "Failed to mint additional tokens"))
            
            ;; Verify updated balance
            (let ((new-balance (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
                (asserts! (is-eq new-balance (+ INITIAL_MINT_AMOUNT u500)) 
                    (err "Balance incorrect after second mint"))
            )
        )

        ;; Test 3: Mint zero tokens
        (let ((zero-mint (contract-call? .curation-tokens mint-tokens TOKEN_OWNER u0)))
            (asserts! (is-err zero-mint) (err "Should fail when minting zero tokens"))
        )

        (ok true)
    )
)

;; Test cases for token transfers
(define-public (test-transfer-tokens)
    (begin
        ;; Setup: Mint initial tokens
        (try! (contract-call? .curation-tokens mint-tokens TOKEN_OWNER INITIAL_MINT_AMOUNT))

        ;; Test 1: Valid transfer
        (let ((transfer-result (contract-call? .curation-tokens transfer-tokens 
                              TOKEN_OWNER TOKEN_RECIPIENT TRANSFER_AMOUNT)))
            (asserts! (is-ok transfer-result) (err "Failed to transfer tokens"))
            
            ;; Verify balances after transfer
            (let ((sender-balance (contract-call? .curation-tokens get-balance TOKEN_OWNER))
                  (recipient-balance (contract-call? .curation-tokens get-balance TOKEN_RECIPIENT)))
                (asserts! (is-eq sender-balance (- INITIAL_MINT_AMOUNT TRANSFER_AMOUNT)) 
                    (err "Sender balance incorrect after transfer"))
                (asserts! (is-eq recipient-balance TRANSFER_AMOUNT) 
                    (err "Recipient balance incorrect after transfer"))
            )
        )

        ;; Test 2: Transfer more than balance
        (let ((invalid-transfer (contract-call? .curation-tokens transfer-tokens 
                               TOKEN_OWNER TOKEN_RECIPIENT (+ INITIAL_MINT_AMOUNT u1))))
            (asserts! (is-err invalid-transfer) 
                (err "Should fail when transferring more than balance"))
        )

        ;; Test 3: Transfer to self
        (let ((self-transfer (contract-call? .curation-tokens transfer-tokens 
                            TOKEN_OWNER TOKEN_OWNER u100)))
            (asserts! (is-ok self-transfer) (err "Failed to transfer to self"))
            
            ;; Verify balance remained the same
            (let ((balance (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
                (asserts! (is-eq balance (- INITIAL_MINT_AMOUNT TRANSFER_AMOUNT)) 
                    (err "Balance changed after self-transfer"))
            )
        )

        ;; Test 4: Transfer zero tokens
        (let ((zero-transfer (contract-call? .curation-tokens transfer-tokens 
                            TOKEN_OWNER TOKEN_RECIPIENT u0)))
            (asserts! (is-err zero-transfer) (err "Should fail when transferring zero tokens"))
        )

        (ok true)
    )
)

;; Test cases for reward distribution
(define-public (test-reward-discovery)
    (begin
        ;; Test 1: Basic reward
        (let ((reward-result (contract-call? .curation-tokens reward-discovery TOKEN_OWNER)))
            (asserts! (is-ok reward-result) (err "Failed to reward discovery"))
            
            ;; Verify reward was added to balance
            (let ((balance (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
                (asserts! (is-eq balance DISCOVERY_REWARD_AMOUNT) 
                    (err "Reward amount not correctly added"))
            )
        )

        ;; Test 2: Multiple rewards
        (let ((second-reward (contract-call? .curation-tokens reward-discovery TOKEN_OWNER)))
            (asserts! (is-ok second-reward) (err "Failed to give second reward"))
            
            ;; Verify cumulative rewards
            (let ((balance (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
                (asserts! (is-eq balance (* DISCOVERY_REWARD_AMOUNT u2)) 
                    (err "Cumulative rewards not calculated correctly"))
            )
        )

        (ok true)
    )
)

;; Test cases for balance checking
(define-public (test-get-balance)
    (begin
        ;; Test 1: Check initial balance
        (let ((initial-balance (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
            (asserts! (is-eq initial-balance u0) (err "Initial balance should be zero"))
        )

        ;; Test 2: Check balance after minting
        (try! (contract-call? .curation-tokens mint-tokens TOKEN_OWNER INITIAL_MINT_AMOUNT))
        (let ((balance-after-mint (contract-call? .curation-tokens get-balance TOKEN_OWNER)))
            (asserts! (is-eq balance-after-mint INITIAL_MINT_AMOUNT) 
                (err "Balance incorrect after minting"))
        )

        ;; Test 3: Check non-existent account
        (let ((non-existent-balance (contract-call? .curation-tokens get-balance 
                                   'ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21XCP)))
            (asserts! (is-eq non-existent-balance u0) 
                (err "Non-existent account should have zero balance"))
        )

        (ok true)
    )
)

;; Integration tests
(define-public (test-full-token-workflow)
    (begin
        ;; 1. Initial minting
        (try! (contract-call? .curation-tokens mint-tokens TOKEN_OWNER INITIAL_MINT_AMOUNT))
        
        ;; 2. Transfer tokens
        (try! (contract-call? .curation-tokens transfer-tokens 
               TOKEN_OWNER TOKEN_RECIPIENT TRANSFER_AMOUNT))
        
        ;; 3. Reward discovery
        (try! (contract-call? .curation-tokens reward-discovery TOKEN_RECIPIENT))
        
        ;; 4. Verify final balances
        (let ((owner-final-balance (contract-call? .curation-tokens get-balance TOKEN_OWNER))
              (recipient-final-balance (contract-call? .curation-tokens get-balance TOKEN_RECIPIENT)))
            
            (asserts! (is-eq owner-final-balance (- INITIAL_MINT_AMOUNT TRANSFER_AMOUNT)) 
                (err "Owner's final balance incorrect"))
            (asserts! (is-eq recipient-final-balance (+ TRANSFER_AMOUNT DISCOVERY_REWARD_AMOUNT)) 
                (err "Recipient's final balance incorrect"))
        )

        (ok true)
    )
)

;; Test edge cases
(define-public (test-edge-cases)
    (begin
        ;; Test 1: Transfer between same account
        (try! (contract-call? .curation-tokens mint-tokens TOKEN_OWNER INITIAL_MINT_AMOUNT))
        (let ((self-transfer (contract-call? .curation-tokens transfer-tokens 
                            TOKEN_OWNER TOKEN_OWNER INITIAL_MINT_AMOUNT)))
            (asserts! (is-ok self-transfer) (err "Self transfer failed"))
        )

        ;; Test 2: Multiple transfers in sequence
        (try! (contract-call? .curation-tokens transfer-tokens 
               TOKEN_OWNER TOKEN_RECIPIENT u100))
        (try! (contract-call? .curation-tokens transfer-tokens 
               TOKEN_RECIPIENT TOKEN_OWNER u50))
        
        ;; Test 3: Reward limits
        (let ((max-reward-test (contract-call? .curation-tokens reward-discovery TOKEN_OWNER)))
            (asserts! (is-ok max-reward-test) (err "Max reward test failed"))
        )

        (ok true)
    )
)

;; Run all tests
(define-public (run-all-tests)
    (begin
        (print "Starting curation token tests...")
        (try! (test-mint-tokens))
        (try! (test-transfer-tokens))
        (try! (test-reward-discovery))
        (try! (test-get-balance))
        (try! (test-full-token-workflow))
        (try! (test-edge-cases))
        (ok "All curation token tests completed successfully!")
    )
)