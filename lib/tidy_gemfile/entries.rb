module TidyGemfile
  class Entry
    include Comparable
    include Enumerable

    DEFAULT_HASH_STYLE  = "1.9".freeze
    DEFAULT_QUOTE_STYLE = '"'.freeze

    attr :command, :argv, :options, :lineno, :priority

    class << self
      def hash_style
        @@hash_style ||= DEFAULT_HASH_STYLE
      end

      def hash_style=(style)
        @@hash_style = style
      end

      def quote_style=(style)
        @@quote_style = style
      end


      def quote_style
        @@quote_style ||= DEFAULT_QUOTE_STYLE
      end
    end

    def initialize(command, argv, lineno, priority)
      @command = command
      @argv = Array(argv)
      @options = normalize_options(@argv.last.is_a?(Hash) ? @argv.pop : {})
      @lineno = lineno
      @priority = priority
    end

    def <=>(other)
      return unless other.is_a?(Entry)
      sort_by(self) <=> sort_by(other)
    end

    def each
      block_given? ? yield(self) : [self].to_enum
    end

    def to_s
      entry_string(self)
    end

    protected

    def entry_string(entry)
      str = entry.argv.map { |v| quote(v) }
      str.concat entry.options.map { |k, v| sprintf "%s %s", key(k), quote(v) }
      sprintf "%s %s", entry.command, str.join(", ")
    end

    def key(s)
      self.class.hash_style == DEFAULT_HASH_STYLE ? "#{s}:" : ":#{s} =>"
    end

    def quote(s)
      case s
      when Symbol
        ":#{s}"
      when Array
        s
      else
        quote = self.class.quote_style
        sprintf("%s%s%s", quote, s, quote)
      end
    end

    private

    def normalize_options(options)
      options.keys.each do |key|
        options[key.to_sym] = options.delete(key) unless key.is_a?(Symbol)
      end
      options
    end

    def sort_by(entry)
      sorter = [entry.priority, entry.command.to_s]
      # TODO: rethink this, though if they're diff types sort will error
      sorter.concat(entry.argv.map(&:to_s))
      sorter.concat(options.to_a)
      #sorter << lineno
    end

    def initialize_copy(c)
      @argv = argv.dup
      @options = options.dup
    end
  end

  class GroupedEntry < Entry
    attr :children

    def initialize(command, argv, lineno, priority, children)
      super(command, argv, lineno, priority)
      @children = children
    end

    def each
      # TODO: no block
      children.each do |child|

        # TODO: Bundler's behavior if a directive contains the option defined by the block?
        child = child.dup
        child.options.merge!(options)
        child.options[command.to_sym] = argv.one? ? argv.first : argv
        yield child
      end
    end

    def to_s
      str = entry_string(self)
      return str unless children.any?

      str << " do\n"
      children.inject(str) { |s, entry| str << "  #{entry}\n" }
      str << "end"
    end
  end
end
