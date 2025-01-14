# Janeway JSONPath parser

### Purpose

This is a [JsonPath](https://goessner.net/articles/JsonPath/) parser.

It reads a JSON input file and a query.
It uses the query to find and return a set of matching values from the input.
This does for JSON the same job that XPath does for XML.

This project includes:
    * command-line tool to run jsonpath queries on a JSON input
    * ruby library to run jsonpath queries on a JSON input

### Goals

* parse Goessner JSONPath, similar to https://github.com/joshbuddy/jsonpath
* implement all of [IETF RFC 9535](https://github.com/ietf-wg-jsonpath)
* raise helpful query parse errors designed to help users understand and improve queries, rather than describing issues in the code
* don't use regular expressions for parsing, for performance
* don't use `eval`, which is known to be an attack vector
* be simple and fast with minimal dependencies
* modern, linted ruby 3 code with frozen string literals

### Non-goals

* Changing behavior to follow [other implementations](https://cburgmer.github.io/json-path-comparison/)

The JSONPath RFC was in draft status for a long time and has seen many changes.
There are many implementations based on older drafts, or which add features that were never in the RFC at all.

The goal is perfect adherence to the finalized [RFC 9535](https://github.com/ietf-wg-jsonpath) rather than adding features that are in other implementations.

The RFC was finalized in 2024, and it has a rigorous [suite of compliance tests.](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite)

With these tools it is possible to have JSONPath implementations in many languages with identical behavior.

### Usage

#### Janeway command-line tool

Give it a query and some input JSON, and it prints a JSON result.
Use single quotes around the JSON query to avoid shell interaction.
Example:

```
    $ janeway '$..book[?(@.price<10)]' example.json
    [
      {
        "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "price": 8.95
      },
      {
        "category": "fiction",
        "author": "Herman Melville",
        "title": "Moby Dick",
        "isbn": "0-553-21311-3",
        "price": 8.99
      }
    ]
```

You can also pipe JSON into it:
```
    $ cat example.json | janeway '$..book[?(@.price<10)]'
```

#### Janeway ruby libarary

Here's an example of using Janeway to execute a JSONPath query in ruby code:
```ruby
require 'janeway'
require 'json'

data = JSON.parse(File.read(ARGV.first))
results = Janeway.find_all('$..book[?(@.price<10)]', data)
```

Alternatively, compile the query once, and share it between threads or ractors.

The Janeway::AST::Query object is not modified after parsing, so it is easy to freeze and share concurrently.

```ruby
    # Create ractors with their own data sources
    ractors =
      Array.new(4) do |index|
        Ractor.new(index) do |i|
          query = receive
          data = JSON.parse File.read("input-file-#{i}.json")
          puts query.find_all(data)
        end
      end

    # Construct JSONPath query object and send it to each ractor
    query = Janeway.compile('$..book[?(@.price<10)]')
    ractors.each { |ractor| ractor.send(query).take }
```

### Porting from joshbuddy/jsonpath

See [Porting](PORTING.md) for tips on converting a ruby project from [joshbuddy/jsonpath](https://github.com/joshbuddy/jsonpath) to janeway.

### Implementation

Functionality is based on [IETF RFC 9535, "JSONPath: Query Expressions for JSON"](https://www.rfc-editor.org/rfc/rfc9535.html#filter-selector)
The examples in the RFC have been implemented as unit tests.

For details not covered in the RFC, it does the most reasonable thing based on [what other JSONPath parsers do](https://cburgmer.github.io/json-path-comparison/). However, this is always secondary to following the RFC. Many of the popular behaviors there contradict the RFC, so it has to be one or the other.
