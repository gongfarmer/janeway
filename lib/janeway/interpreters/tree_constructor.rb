# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Constructs a tree of interpreter objects.
    #
    # It is used when an iterator method such as #each has been called to
    # construct the chain of interpreter objects to handle the query.
    module TreeConstructor
      # Fake interpreter which just returns the given value
      Literal = Struct.new(:value) do
        def interpret(*)
          value
        end
        alias_method :node, :interpret
      end

      # Return an interpreter for the given AST node.
      # This interpreter forwards matcheed values to the next interpreter, or
      # returns them if there is no next interpreter.
      #
      # @param expr [AST::Expression]
      # @return [Interprteters::Base]
      def self.ast_node_to_interpreter(expr)
        case expr
        when AST::RootNode then Interpreters::RootNodeInterpreter.new(expr)
        when AST::ArraySliceSelector then Interpreters::ArraySliceSelectorInterpreter.new(expr)
        when AST::IndexSelector then Interpreters::IndexSelectorInterpreter.new(expr)
        when AST::NameSelector then Interpreters::NameSelectorInterpreter.new(expr)
        when AST::WildcardSelector then Interpreters::WildcardSelectorInterpreter.new(expr)
        when AST::FilterSelector then Interpreters::FilterSelectorInterpreter.new(expr)
        when AST::ChildSegment then Interpreters::ChildSegmentInterpreter.new(expr)
        when AST::DescendantSegment then Interpreters::DescendantSegmentInterpreter.new(expr)
        when AST::BinaryOperator then Interpreters::BinaryOperatorInterpreter.new(expr)
        when AST::UnaryOperator then Interpreters::UnaryOperatorInterpreter.new(expr)
        when AST::CurrentNode then Interpreters::CurrentNodeInterpreter.new(expr)
        when AST::Function then Interpreters::FunctionInterpreter.new(expr)
        when AST::StringType, AST::Number, AST::Null, AST::Boolean then Literal.new expr.value
        when nil then nil # caller has no @next node
        else
          raise "Unknown AST expression: #{expr.inspect}"
        end
      end

      # Return a Deleter interpreter for the given AST node.
      # This interpreter deletes matched values.
      #
      # @param expr [AST::Expression]
      # @return [Interprteters::Base]
      def self.ast_node_to_deleter(expr)
        case expr
        when AST::IndexSelector then IndexSelectorDeleter.new(expr)
        when AST::ArraySliceSelector then ArraySliceSelectorDeleter.new(expr)
        when AST::NameSelector then NameSelectorDeleter.new(expr)
        when AST::FilterSelector then FilterSelectorDeleter.new(expr)
        when AST::WildcardSelector then WildcardSelectorDeleter.new(expr)
        when AST::ChildSegment then ChildSegmentDeleter.new(expr)
        when AST::RootNode then RootNodeDeleter.new(expr)
        when nil then nil # caller has no @next node
        else
          raise "Unknown AST expression: #{expr.inspect}"
        end
      end

      # Return a DeleteIf interpreter for the given AST node.
      # This interpreter deletes matched values, but only after
      # yielding to a block that returns a truthy value.
      #
      # @param expr [AST::Expression]
      # @return [Interprteters::Base]
      def self.ast_node_to_delete_if(expr, &block)
        case expr
        when AST::IndexSelector then IndexSelectorDeleteIf.new(expr, &block)
        when AST::ArraySliceSelector then ArraySliceSelectorDeleteIf.new(expr, &block)
        when AST::NameSelector then NameSelectorDeleteIf.new(expr, &block)
        when AST::FilterSelector then FilterSelectorDeleteIf.new(expr, &block)
        when AST::WildcardSelector then WildcardSelectorDeleteIf.new(expr, &block)
        when AST::ChildSegment then ChildSegmentDeleteIf.new(expr, &block)
        when AST::RootNode then RootNodeDeleteIf.new(expr, &block)
        else
          raise "Unknown AST expression: #{expr.inspect}"
        end
      end
    end
  end
end
