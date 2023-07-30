Jsonpath parser

Goals:
* follow IETF draft standard: https://github.com/ietf-wg-jsonpath
* parse Goessner jsonpath, similar to https://github.com/joshbuddy/jsonpath
* don't use regular expressions during parsing
* simple
* behave "normally" based on https://cburgmer.github.io/json-path-comparison/

Parser / lexer based on: https://www.honeybadger.io/blog/building-lexer-ruby/
