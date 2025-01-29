# Janeway JSONPath parser

This is a [JSONPath](https://goessner.net/articles/JsonPath/) parser.
It strictly follows [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535.html) and passes the [JSONPath Compliance Test Suite](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite).

It reads a JSON input file and a query, and uses the query to find and return a set of matching values from the input.
This does for JSON the same job that XPath does for XML.

This project includes:

    * ruby library to run jsonpath queries on a JSON input
    * command-line tool to do the same

**Contents**

- [Install](#install)
- [Usage](#usage)
- [Related projects](#related-projects)
- [Goals](#goals)
- [Non-goals](#non-goals)

### Install

Install the gem from the command-line:
```
    gem install janeway-jsonpath
```

or add it to your Gemfile:

```
    gem 'janeway-jsonpath', '~> 0.4.0'
```

### Usage

#### Janeway command-line tool

Give it a query and some input JSON, and it prints a JSON result.
Use single quotes around the JSON query to avoid shell interaction.
Example:

```
    $ cat store.json
    { "store": {
        "book": [
          { "category": "reference",
            "author": "Nigel Rees",
            "title": "Sayings of the Century",
            "price": 8.95
          },
          { "category": "fiction",
            "author": "Evelyn Waugh",
            "title": "Sword of Honour",
            "price": 12.99
          },
          { "category": "fiction",
            "author": "Herman Melville",
            "title": "Moby Dick",
            "isbn": "0-553-21311-3",
            "price": 8.99
          },
          { "category": "fiction",
            "author": "J. R. R. Tolkien",
            "title": "The Lord of the Rings",
            "isbn": "0-395-19395-8",
            "price": 22.99,
            "value": true
          }
        ],
        "bicycle": {
          "color": "red",
          "price": 399
        }
      }
    }


    ### Find and return matching values
    $ janeway '$..book[?(@["price"] == 8.95 || @["price"] == 8.99)].title' store.json
    [
      "Sayings of the Century",
      "Moby Dick"
    ]

    ### Delete matching values from the input, print what remains
    $ janeway -d '$.store.book' store.json
    {
      "store": {
        "bicycle": {
          "color": "red",
          "price": 399
        }
      }
    }
```

You can also pipe JSON into it:
```
    $ cat store.json | janeway '$..book[?(@.price<10)]'
```

See the help message for more capabilities: `janeway --help`

#### Janeway ruby libarary

Here's an example of ruby code using Janeway to find values from a JSON document:
To use the Janeway library in ruby code, providing a jsonpath query and an input object (Hash or Array) to search.
```ruby
    require 'janeway'
    require 'json'

    data = JSON.parse(File.read(ARGV.first))
    Janeway.enum_for('$.store.book[0].title', data)
```
This returns an Enumerator, which offers instance methods for using the query to operate on matching values in the input object.

Following are examples showing how to work with the Enumerator methods.

##### #search

Returns all values that match the query.

```ruby
    results = Janeway.enum_for('$..book[?(@.price<10)]', data).search
    # Returns every book in the store cheaper than $10
```

Alternatively, compile the query once, and share it between threads or ractors with different data sources:

```ruby
    # Create ractors with their own data sources
    ractors =
      Array.new(4) do |index|
        Ractor.new(index) do |i|
          query = receive
          data = JSON.parse File.read("input-file-#{i}.json")
          puts query.enum_for(data).search
        end
      end

    # Construct JSONPath query object and send it to each ractor
    query = Janeway.compile('$..book[?(@.price<10)]')
    ractors.each { |ractor| ractor.send(query).take }
```

##### #each

Iterates through matches one by one, without holding the entire set in memory.
Janeway's #each iteration is particularly powerful, as it provides context for each match.
The matched value is yielded:
```ruby
    data = {
        'birds' => ['eagle', 'stork', 'cormorant'] }
        'dogs' => ['poodle', 'pug', 'saint bernard'] },
    }
    Janeway.enum_for('$.birds.*', data).each do |bird|
      puts "the bird is a #{bird}"
    end
```

This allows the matched value to be modified in place:
```ruby
    Janeway.enum_for('$.birds[? @=="storck"]', data).each do |bird|
      bird.gsub!('ck', 'k') # Fix a typo: "storck" => "stork"
    end
    # input list is now ['eagle', 'stork', 'cormorant']
```

However, this is not enough to replace the matched value:
```ruby
    Janeway.enum_for('$.birds', data).each do |bird|
      bird = "bald eagle" if bird == 'eagle'
      # local variable 'bird' now points to a new value, but the original list is unchanged
    end
    # input list is still ['eagle', 'stork', 'cormorant']
```

The second and third yield parameters are the object that contains the value, and the array index or hash key of the value.
This allows the list or hash to be modified:
```ruby
    Janeway.enum_for('$.birds[? @=="eagle"]', data).each do |_bird, parent, index|
      parent[index] = "golden eagle"
    end
    # input list is now ['golden eagle', 'stork', 'cormorant']
```

Lastly, the #each iterator's fourth yield parameter is the [normalized path](https://www.rfc-editor.org/rfc/rfc9535.html#name-normalized-paths) to the matched value.
This is a jsonpath query string that uniquely points to the matched value.

```ruby
    # Collect the normalized path of every object in the input, at all levels
    paths = []
    Janeway.enum_for('$..*', data).each do |_bird, _parent, _index, path| do
        paths << path
    end
    paths
    # ["$['birds']", "$['dogs']", "$['birds'][0]", "$['birds'][1]", "$['birds'][2]", "$['dogs'][0]", "$['dogs'][1]", "$['dogs'][2]"]
```

##### #delete

The '#delete' method deletes matched values from the input.
```ruby
    # delete any bird whose name is "eagle" or starts with "s"
    Janeway.enum_for('$.birds[? @=="eagle" || search(@, "^s")]', data).delete
    # input bird list is now ['cormorant']

    # delete all dog names
    Janeway.enum_for('$.dogs.*', data).delete
    # dog list is now []
```


The `Janeway.enum_for` and `Janeway::Query#on` methods return an enumerator, so you can use the usual ruby enumerator methods, such as:

#####  #map
Return the matched elements, as modified by the block.

```ruby
    # take a dollar off every price in the store
    sale_prices = Janeway.enum_for('$.store..price', data).map { |price| price - 1 }
    # [7.95, 11.99, 7.99, 21.99, 398]
```

#####  #select (alias #find_all)

Return only values that match the JSONPath query and also return a truthy value from the block.
This solves a common JSON problem: You want to do a numeric comparison on a value in your JSON, but the JSON value is stored as a string type.

```ruby
    # Poorly serialized, the prices are strings
    data =
      { "store" => {
          "book" => [
             { "title" => "Sayings of the Century", "price" => "8.95" },
             { "title" => "Sword of Honour", "price" => "12.99" },
             { "title" => "Moby Dick", "price" => "8.99" },
             { "title" => "The Lord of the Rings", "price" => "22.99" },
          ]
        }
      }

    # Can't use a filter query with a numeric comparison on a string price
    Janeway.enum_for('$.store.book[? @.price > 10.00]', data).find_all
    # result: []

    # Solve the problem with ruby by filtering with #select and converting string to number:
    Janeway.enum_for('$.store.book.*', data).select { |book| book['price'].to_f > 10 }
    # result: [{"title" => "Sword of Honour", "price" => "12.99"}, {"title" => "The Lord of the Rings", "price" => "22.99"}]
```

#####  #reject

Return only values that match the JSONPath query and also return false from the block.

#####  #filter_map

Combines #select and #map.
Return values that match the jsonpath query and return truthy values from the block.
Instead of returning the value from the data, return the result of the block.

#####  #find 

Return the first value that matches the jsonpath query and also returns a truthy value from the block
```ruby
    Janeway.enum_for('$.store.book[? @.price >= 10.99]', data).find { |book| book['title'].start_with?('T') }
    # [ "The Lord of the Rings" ]
```

There are many other Enumerable methods too, see the ruby Enumerable module documenation for more.

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
* idiomatic, linted ruby 3 code with frozen string literals everywhere

### Non-goals

* Changing behavior to follow [other implementations](https://cburgmer.github.io/json-path-comparison/)

The JSONPath RFC was in draft status for a long time and has seen many changes.
There are many implementations based on older drafts, and others which add features that were never in the RFC at all.

The goal is adherence to the [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535.html) rather than adding features that are in other implementations. This implementation's results are supposed to be identical to other RFC-compliant implementations in [dart](https://github.com/f3ath/jessie), [python](https://github.com/jg-rp/python-jsonpath-rfc9535) and other languages.

The RFC was finalized in 2024. With the finalized RFC and the rigorous [suite of compliance tests](https://github.com/jsonpath-standard/jsonpath-compliance-test-suite), it is now possible to have JSONPath implementations in many languages with identical behavior.
