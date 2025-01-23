# frozen_string_literal: true

module Janeway
  # Converts index and name selector values to normalized path components.
  #
  # This implements the normalized path description in RFC 9535:
  # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-normalized-paths
  #
  # This does a lot of escaping, and much of it is the inverse of Lexer code that does un-escaping.
  module NormalizedPath
    # Characters that do not need escaping, defined by hexadecimal range
    NORMAL_UNESCAPED_RANGES = [(0x20..0x26), (0x28..0x5B), (0x5D..0xD7FF), (0xE000..0x10FFFF)].freeze

    def self.normalize(value)
      case value
      when String then normalize_name(value)
      when Integer then normalize_index(value)
      else
        raise "Cannot normalize #{value.inspect}"
      end
    end

    # @param index [Integer] index selector value
    # @return [String] eg. "[1]"
    def self.normalize_index(index)
      "[#{index}]"
    end

    # @param name [Integer] name selector value
    # @return [String] eg. "['']"
    def self.normalize_name(name)
      "['#{escape(name)}']"
    end

    def self.escape(str)
      # Common case, all chars are normal.
      return str if str.chars.all? { |char| NORMAL_UNESCAPED_RANGES.any? { |range| range.include?(char.ord) } }

      # Some escaping must be done
      str.chars.map { |char| escape_char(char) }.join
    end

    # Escape or hex-encode the given character
    # @param char [String] single character, possibly multi-byte
    # @return [String]
    def self.escape_char(char)
      # Character ranges defined by https://www.rfc-editor.org/rfc/rfc9535.html#section-2.7-8
      case char.ord
      when 0x20..0x26, 0x28..0x5B, 0x5D..0xD7FF, 0xE000..0x10FFFF # normal-unescaped range
        char # unescaped
      when 0x62, 0x66, 0x6E, 0x72, 0x74, 0x27, 0x5C # normal-escapable range
        # backspace, form feed, line feed, carriage return, horizontal tab, apostrophe, backslash
        "\\#{char}" # escaped
      else # normal-hexchar range
        hex_encode_char(char)
      end
    end

    # Hex-encode the given character
    # @param char [String] single character, possibly multi-byte
    # @return [String]
    def self.hex_encode_char(char)
      format('\\u00%02x', char.ord)
    end
  end
end
