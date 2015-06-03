require "ripper"
require "bundler"
require "tidy_gemfile/entries"

module TidyGemfile
  class Parser
    def initialize(config)
      @config = config
      @bundler = Bundler::Dsl.new
    end

    def parse(path)
      tree = load_gemfile(path)
      tree[1].map { |n| process(n[0], n[1..-1]) }
    end

    private

    def load_gemfile(path)
      gemfile = File.read(path)

      begin
        @bundler.eval_gemfile(path, gemfile)
      rescue Bundler::GemfileError => e
        raise ParseError, e.message
      end

      # After the above we should not get nil
      tree = Ripper.sexp(gemfile)
      raise ParseError, "run `ruby -c' and correct the syntax errors" unless tree

      tree
    end

    def process(action, args)
      raise ParseError, "statements of type '#{action}' are not supported" unless respond_to?(action, true)
      send(action, args)
    end

    def lineno(node)
      node[0][-1][0]
    end

    def scalar(node)
      s = node[1][1]
      node[0] == :symbol ? s.to_sym : s
    end

    def options(nodes)
      nodes.each_with_object({}) do |node, options|
        # [:assoc_new, [:symbol_literal, ...  ], [:string_literal, ... ]]
        # [:assoc_new, [:symbol_literal, ...  ], [:array         , ... ]]

        # TODO: consolidate under scalar where appropriate
        key = node[1][0] == :@label ? node[1][1][0..-2].to_sym : scalar(node[1][1])
        val = case node[2][0]
              when :array
                node[2][1].map { |e| e[1] }
              when :@int
                node[2][1].to_i
              when :@float
                node[2][1].to_f
              else
                scalar(node[2][1])
              end

        options[key] = val
      end
    end

    def args_add_block(node)
      node.map do |n|
        if n[0] == :bare_assoc_hash
          options(n[1])
        else
          scalar(n[1])
        end
      end
    end

    # [:@ident, "group", [5, 0]], [:args_add_block, ... ]
    def command(node)
      command = node[0][1]
      lineno  = lineno(node)
      argv    = []

      if node.size > 1 && node[1][0] == :args_add_block
        # Ignore last element which is (always?) false
        argv = args_add_block(node[1][1])
      end

      Entry.new(command, argv, lineno, @config[command])
    end

    alias :vcall :command

    # [:fcall, [:@ident, "group", [28, 0]]]
    def method_add_arg(node)
      # Massage it to work with command
      command([node[0][1]])
    end

    def method_add_block(node)
      entry    = process(node[0][0], node[0][1..-1])
      argv     = node[0][0] == :method_add_arg ? [] : args_add_block(node[0][2][1])
      children = node[1][2] == [[:void_stmt]]  ? [] : node[1][2].map { |n| process(n[0], n[1..-1]) }

      GroupedEntry.new(entry.command, entry.argv, entry.lineno, entry.priority, children)
    end
  end
end
