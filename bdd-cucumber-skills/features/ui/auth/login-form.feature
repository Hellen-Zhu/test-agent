Feature: Login form behaviour
  Browser-side validation, password masking, and submission state
  for the /login page.

  Background:
    Given I am on the "/login" page

  Scenario: Successful submission disables the button while in flight
    When I fill "email" with "jane@example.com"
    And I fill "password" with "Correct-Horse-Battery-9!"
    And I click the "Sign in" button
    Then the "Sign in" button becomes disabled within 100 ms
    And the button is re-enabled after the request completes

  Scenario: Invalid credentials show an inline error and do not navigate
    When I fill "email" with "jane@example.com"
    And I fill "password" with "wrong-password"
    And I click the "Sign in" button
    Then I see the inline error "Invalid email or password"
    And the URL is still "/login"
    And focus returns to the password field

  Scenario: Email field validates shape on blur
    When I fill "email" with "not-an-email"
    And I move focus away from the email field
    Then I see the inline error "Please enter a valid email address" near the email field

  Scenario: Password field is masked by default and can be toggled
    Then the "password" field has type "password"
    When I click the show/hide password toggle
    Then the "password" field has type "text"
    When I click the show/hide password toggle again
    Then the "password" field has type "password"

  Scenario: Submitting with empty fields highlights both
    When I click the "Sign in" button
    Then the "email" field is marked invalid
    And the "password" field is marked invalid
    And no network request is sent
