require "ripper"
require "tidy_gemfile/entries"

module TidyGemfile
  class Parser
    def initialize(config)
      @config = config
    end

    def parse(path)
      tree = Ripper.sexp(File.read(path))
      raise ParseError, "run `ruby -c' and correct the syntax errors" unless tree

      tree[1].flat_map do |n|
        raise ParseError, "unknown directive #{n[0]}" unless respond_to?(n[0], true)
        send(n[0], n[1..-1])
      end
    end

    private

    def lineno(node)
      node[0][-1][0]
    end

    def scalar(node)
      s = node[1][1]
      node[0] == :symbol ? s.to_sym : s
    end

    def array(node)
      node.map { |e| scalar(e[1]) }
    end

    def options(nodes)
      nodes.each_with_object({}) do |node, options|
        # [:assoc_new, [:symbol_literal, ...  ], [:string_literal, ... ]]
        # [:assoc_new, [:symbol_literal, ...  ], [:array         , ... ]]

        # TODO: consolidate under scalar where appropriate
        key = node[1][0] == :@label ? node[1][1][0..-2].to_sym : scalar(node[1][1])
        val = case node[2][0]
              when :array
                array(node[2][1])
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

    # URL can have user/pass
    def source(node, lineno)
      # ... unless node[0][0] == :args_add_block
      Entry.new("source", scalar(node[0][1][0][1]), lineno, @config["source"])
    end

    def ruby(node, lineno)
      Entry.new("ruby", scalar(node[0][1][0][1]), lineno, @config["ruby"])
    end

    def gem(node, lineno)
      # ... unless node[0][0] == :args_add_block
      argv = node[0][1].map do |n|
        if n[0] == :bare_assoc_hash
          options(n[1])
        else
          scalar(n[1])
        end
      end

      Entry.new("gem", argv, lineno, @config["gem"])
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
      function = node[0][1]
      lineno   = lineno(node)

      send(function, node[1..-1], lineno)
    end

    # source, group or path
    def method_add_block(node)
      command = node[0][1][1]
      lineno = lineno(node)

      argv = args_add_block(node[0][2][1])
      children = node[1][2].map { |n| send(n[0], n[1..-1]) }

      GroupedEntry.new(command, argv, lineno, @config[command]||1, children)
    end

    def void_stmt(node)
      []
    end
  end
end
