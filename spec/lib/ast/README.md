### AST classes

## #to_s
* classes must implement #to_s for use by unit tests.
* this allows a compact but readable representation that makes the tests easier to understand and write
* round-trip through #to_s is not required to reproduce the original. #to_s may add more explicit grouping mechanisms to make their meaning unambiguous.
* this is not used in the actual jsonpath output

