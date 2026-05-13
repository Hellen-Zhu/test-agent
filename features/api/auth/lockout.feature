Feature: Account lockout after repeated failed sign-ins
  Protect against brute-force credential guessing by locking accounts
  after 5 failed attempts inside a 10-minute sliding window.

  Background:
    Given a registered user "jane@example.com" with password "Correct-Horse-Battery-9!"
    And the failed-login counter for "jane@example.com" is reset

  Scenario: 5 failures within 10 minutes lock the account
    When I POST 5 times to "/api/v1/auth/login" with an incorrect password within 1 minute
    Then each of the first 5 responses has status 401
    And a subsequent POST to "/api/v1/auth/login" with the CORRECT password returns 423
    And the response body has "error.code" equal to "account_locked"
    And the response includes a "Retry-After" header

  Scenario: 4 failures do not lock the account
    When I POST 4 times to "/api/v1/auth/login" with an incorrect password within 1 minute
    And I POST to "/api/v1/auth/login" with the CORRECT password
    Then the response status is 200

  Scenario: Failures more than 10 minutes apart do not accumulate
    When I POST to "/api/v1/auth/login" with an incorrect password
    And 11 minutes pass
    And I POST 4 times to "/api/v1/auth/login" with an incorrect password
    Then the account is NOT locked
    And a subsequent POST with the CORRECT password returns 200

  Scenario: Locked account stays locked even with correct password
    Given the account "jane@example.com" is currently locked
    When I POST to "/api/v1/auth/login" with body:
      """
      { "email": "jane@example.com", "password": "Correct-Horse-Battery-9!" }
      """
    Then the response status is 423
    And the response body has "error.code" equal to "account_locked"
