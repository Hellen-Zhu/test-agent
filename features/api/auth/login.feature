Feature: Sign-in API authenticates valid credentials
  As the auth service
  I want to verify email/password and issue a JWT
  So that downstream services can identify the caller

  Background:
    Given a registered user "jane@example.com" with password "Correct-Horse-Battery-9!"

  Scenario: Successful login returns a signed JWT
    When I POST to "/api/v1/auth/login" with body:
      """
      { "email": "jane@example.com", "password": "Correct-Horse-Battery-9!" }
      """
    Then the response status is 200
    And the response body has a "token" field containing a signed JWT
    And the JWT "sub" claim equals the user's id
    And the response time is under 500 ms

  Scenario: Wrong password returns 401 with a stable error code
    When I POST to "/api/v1/auth/login" with body:
      """
      { "email": "jane@example.com", "password": "wrong-password" }
      """
    Then the response status is 401
    And the response body has "error.code" equal to "invalid_credentials"
    And the response body does NOT contain the word "user"

  Scenario: Unknown email returns 401 (no user enumeration)
    When I POST to "/api/v1/auth/login" with body:
      """
      { "email": "nobody@example.com", "password": "anything" }
      """
    Then the response status is 401
    And the response body has "error.code" equal to "invalid_credentials"

  Scenario: Malformed payload returns 400
    When I POST to "/api/v1/auth/login" with body:
      """
      { "email": "jane@example.com" }
      """
    Then the response status is 400
    And the response body has "error.code" equal to "validation_error"
