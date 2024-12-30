# jsonpath parser

### Goals
* parse Goessner JSONPath, similar to https://github.com/joshbuddy/jsonpath
* implement all of [IETF RFC 9535](https://github.com/ietf-wg-jsonpath)
* behave "normally" based on https://cburgmer.github.io/json-path-comparison/
* don't use regular expressions for parsing, for performance
* don't use `eval`, which is known to be an attack vector
* be simple and fast with minimal dependencies

### Implementation

Functionality is based on [IETF RFC 9535, "JSONPath: Query Expressions for JSON"](https://www.rfc-editor.org/rfc/rfc9535.html#filter-selector)
The examples in the RFC have been implemented as unit tests.

For details not covered in the RFC, it does the most reasonable thing based on [what other JSONPath parsers do.](https://cburgmer.github.io/json-path-comparison/)

The parser / lexer / interpreter structure is based on the article [building a toy programming language in ruby](https://www.honeybadger.io/blog/stoffle-introduction/)
