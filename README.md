Jsonpath parser

Goals:
* parse Goessner jsonpath, similar to https://github.com/joshbuddy/jsonpath
* implement the complete IETF standard: https://github.com/ietf-wg-jsonpath
* behave "normally" based on https://cburgmer.github.io/json-path-comparison/
* don't use regular expressions during parsing, for performance
* don't use `eval`, which is known to be an attack vector
* be simple

Parser / lexer based on: https://www.honeybadger.io/blog/building-lexer-ruby/
