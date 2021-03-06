  Scenario: Create business concept related to other business concepts
    Given an existing Domain called "My Parent Domain"
    And an existing Domain called "My Domain" child of Domain "My Parent Domain"
    And an existing Business Concept type called "Business_Term" with empty definition
    And an existing Business Concept of type "Business_Term" in the Domain "My Domain" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Target Term         |
      | Description | This is my target term |
    And the business concept with name "My Target Term" of type "Business_Term" has been submitted for approval
    And the business concept with name "My Target Term" of type "Business_Term" has been published
    When "app-admin" tries to create a business concept in the Domain "My Domain" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Origin Term         |
      | Description | This is my origin term |
      | Related To  | My Target Term         |
    Then the system returns a result with code "Created"
    And "app-admin" is able to view business concept "My Origin Term" of type "Business_Term" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Origin Term         |
      | Description | This is my origin term |
      | Related To  | My Target Term         |

  Scenario: Can not create a relation between not published business concepts
    Given an existing Domain called "My Parent Domain"
    And an existing Domain called "My Domain" child of Domain "My Parent Domain"
    And an existing Business Concept type called "Business_Term" with empty definition
    And an existing Business Concept of type "Business_Term" in the Domain "My Domain" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Target Term         |
      | Description | This is my Target Term |
    When "app-admin" tries to create a business concept in the Domain "My Domain" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Origin Term         |
      | Description | This is my origin term |
      | Related To  | My Target Term         |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Can not create a relation between diferent type business concepts
    Given an existing Domain called "My Parent Domain"
    And an existing Domain called "My Domain" child of Domain "My Parent Domain"
    And an existing Business Concept type called "Origin_Type" with empty definition
    And an existing Business Concept type called "Target_Type" with empty definition
    And an existing Business Concept of type "Target_Type" in the Domain "My Domain" with following data:
      | Field       | Value                  |
      | Type        | Target_Type            |
      | Name        | My Target Term         |
      | Description | This is my Target Term |
    And the business concept with name "My Target Term" of type "Target_Type" has been submitted for approval
    And the business concept with name "My Target Term" of type "Target_Type" has been published
    When "app-admin" tries to create a business concept in the Domain "My Domain" with following data:
      | Field       | Value                  |
      | Type        | Origin_Type            |
      | Name        | My Origin Term         |
      | Description | This is my origin term |
      | Related To  | My Target Term         |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Modify business concept related to other business concepts
    Given an existing Domain called "My Parent Domain"
    And an existing Domain called "My Domain" child of Domain "My Parent Domain"
    And an existing Business Concept type called "Business_Term" with empty definition
    And an existing Business Concept of type "Business_Term" in the Domain "My Domain" with following data:
      | Field       | Value                    |
      | Type        | Business_Term            |
      | Name        | My Target_1 Term         |
      | Description | This is my Target Term 1 |
    And the business concept with name "My Target_1 Term" of type "Business_Term" has been submitted for approval
    And the business concept with name "My Target_1 Term" of type "Business_Term" has been published
    And an existing Business Concept of type "My Target Term" in the Domain "My Domain" with following data:
      | Field       | Value                    |
      | Type        | Business_Term            |
      | Name        | My Target_2 Term         |
      | Description | This is my Target Term 2 |
    And the business concept with name "My Target_2 Term" of type "Business_Term" has been submitted for approval
    And the business concept with name "My Target_2 Term" of type "Business_Term" has been published
    And an existing Business Concept of type "Business_Term" in the Domain "My Domain" with following data:
      | Field       | Value                              |
      | Type        | Business_Term                      |
      | Name        | My Origin Term                     |
      | Description | This is my Origin Term             |
      | Related To  | My Target_1 Term, My Target_2 Term |
    When "app-admin" tries to modify a business concept "My Origin Term" of type "Business_Term" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Origin Term         |
      | Description | This is my Origin Term |
      | Related To  | My Target_1 Term       |
    Then the system returns a result with code "Ok"
    And "app-admin" is able to view business concept "My Origin Term" of type "Business_Term" with following data:
      | Field       | Value                  |
      | Type        | Business_Term          |
      | Name        | My Origin Term         |
      | Description | This is my Origin Term |
      | Related To  | My Target_1 Term       |
