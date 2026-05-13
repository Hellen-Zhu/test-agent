Feature: Redirect to dashboard after successful sign-in
  After a successful login the user lands on /dashboard within 2 seconds,
  honouring any deep-link "next" parameter that was present on /login.

  Background:
    Given the user "jane@example.com" with password "Correct-Horse-Battery-9!" exists

  Scenario: Valid credentials redirect to /dashboard within 2 seconds
    Given I am on the "/login" page
    When I fill "email" with "jane@example.com"
    And I fill "password" with "Correct-Horse-Battery-9!"
    And I click the "Sign in" button
    Then the URL becomes "/dashboard" within 2000 ms
    And the dashboard greets "Jane"

  Scenario: Deep-link parameter is preserved through login
    Given I am on the "/login?next=%2Forders%2F123" page
    When I fill "email" with "jane@example.com"
    And I fill "password" with "Correct-Horse-Battery-9!"
    And I click the "Sign in" button
    Then the URL becomes "/orders/123" within 2000 ms

  Scenario: Open-redirect attempt is rejected
    Given I am on the "/login?next=https%3A%2F%2Fevil.example.com" page
    When I fill "email" with "jane@example.com"
    And I fill "password" with "Correct-Horse-Battery-9!"
    And I click the "Sign in" button
    Then the URL becomes "/dashboard" within 2000 ms
    And the URL host is the same origin as "/login"

  Scenario: Already-authenticated users skip the form
    Given I have a valid session cookie
    When I navigate to "/login"
    Then I am redirected to "/dashboard" within 1000 ms
