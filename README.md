# jsonpath parser

### Purpose

This is a [JsonPath](https://goessner.net/articles/JsonPath/) interpreter.

It reads a JSON input file and a query.
It uses the query to find and return a set of matching values from the input.
This does for JSON the same job that XPath does for XML.

This project includes:
    * command-line tool to run jsonpath queries on a JSON input
    * ruby library to run jsonpath queries on a JSON input

### Goals

* parse Goessner JSONPath, similar to https://github.com/joshbuddy/jsonpath
* implement all of [IETF RFC 9535](https://github.com/ietf-wg-jsonpath)
* don't use regular expressions for parsing, for performance
* don't use `eval`, which is known to be an attack vector
* be simple and fast with minimal dependencies
* use helpful query parse errors which help understand and improve queries, rather than describing issues in the code
* modern, linted ruby 3 code with frozen string literals

### Non-goals

* Optimizing behavior based on [other implementations] (https://cburgmer.github.io/json-path-comparison/)

The JSONPath RFC was in draft status for a long time and has seen many changes.
There are many implementations based on older drafts, or which add features that were never in the RFC at all.

The goal here is perfect adherence to [IETF RFC 9535](https://github.com/ietf-wg-jsonpath) rather than adding features that are in other implementations.

The RFC was finalized in 2024, and it has a rigorous [suite of compliance tests.](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite)

With these tools it is possible to have JSONPath implementations in many languages with identical behavior.

### Implementation

Functionality is based on [IETF RFC 9535, "JSONPath: Query Expressions for JSON"](https://www.rfc-editor.org/rfc/rfc9535.html#filter-selector)
The examples in the RFC have been implemented as unit tests.

For details not covered in the RFC, it does the most reasonable thing based on [what other JSONPath parsers do.](https://cburgmer.github.io/json-path-comparison/). However, this is always secondary to following the RFC. Many of the recommended behaviors there contradict the RFC.
