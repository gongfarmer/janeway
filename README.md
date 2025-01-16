# Janeway JSONPath parser

This is a [JsonPath](https://goessner.net/articles/JsonPath/) parser.
It strictly follows [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535.html) and passes the [JSONPath Compliance Test Suite](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite).

It reads a JSON input file and a query, and uses the query to find and return a set of matching values from the input.
This does for JSON the same job that XPath does for XML.

This project includes:

    * command-line tool to run jsonpath queries on a JSON input
    * ruby library to run jsonpath queries on a JSON input

**Contents**

- [Install](#install)
- [Usage](#usage)
- [Related projects](#related-projects)
- [Goals](#goals)
- [Non-goals](#non-goals)

### Install

Install the gem from the command-line:
```
    gem install janeway-jsonpath`
```

or add it to your Gemfile:

```
    gem 'janeway-jsonpath', '~> 0.2.0'
```

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

See the help message for more capabilities: `janeway --help`

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

### Related Projects

- [joshbuddy/jsonpath](https://github.com/joshbuddy/jsonpath)

This is the classic 'jsonpath' ruby gem. It has been around since 2008.
It is not compliant with RFC 9535, because it was written long before the standard was finalized, but it's a capable and useful parser and has long been the best jsonpath library available for ruby.

See [Porting](PORTING.md) for tips on converting a ruby project from [joshbuddy/jsonpath](https://github.com/joshbuddy/jsonpath) to janeway.

- [JPT - reference implementation based on parsing the ABNF grammar of RFC 9535](https://github.com/cabo/jpt)

Also there are many non-ruby implementations of RFC 9535, here are just a few:
- [jesse (dart)](https://github.com/f3ath/jessie)
- [python-jsonpath-rfc9535 (python)](https://github.com/jg-rp/python-jsonpath-rfc9535)
- [theory/jsonpath (go)](https://github.com/theory/jsonpath)

### Goals

* maintain perfect compliance with [IETF RFC 9535](https://www.rfc-editor.org/rfc/rfc9535.html)
* raise helpful query parse errors designed to help users understand and improve queries, rather than describing issues in the code
* don't use regular expressions for parsing, for performance
* don't use `eval`, which is known to be an attack vector
* be simple and fast with minimal dependencies
* provide ruby-like accessors (eg. #each, #delete_if) for processing results
* modern, linted ruby 3 code with frozen string literals

### Non-goals

* Changing behavior to follow [other implementations](https://cburgmer.github.io/json-path-comparison/)

The JSONPath RFC was in draft status for a long time and has seen many changes.
There are many implementations based on older drafts, and others which add features that were never in the RFC at all.

The goal is adherence to the [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535.html) rather than adding features that are in other implementations. This implementation's results are supposed to be identical to other RFC-compliant implementations in [dart](https://github.com/f3ath/jessie), [python](https://github.com/jg-rp/python-jsonpath-rfc9535) and other languages.

The RFC was finalized in 2024. With the finalized RFC and the rigorous [suite of compliance tests](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite), it is now possible to have JSONPath implementations in many languages with identical behavior.
