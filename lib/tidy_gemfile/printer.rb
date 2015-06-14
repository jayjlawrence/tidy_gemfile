require "tidy_gemfile/entries"

module TidyGemfile
  class Printer
    def initialize(config)
      @config = config
      @out = @config[:output] || $stdout
    end

    def print(entries)
      groups = normalize_entries(entries)
      results = groups.values.flatten.sort

      @out.puts results[0]

      results.each_cons(2) do |prev, cur|
        @out.print "\n" if new_section?(prev, cur)
        @out.puts cur
      end
    end

    private

    def new_section?(prev, cur)
      # Always separate blocks by an empty line. Blocks have entries > 1
      # Keep source calls without blocks and ruby calls grouped, but separate them from gem calls
      prev.entries.size > 1 || cur.entries.size > 1 ||
        %w[source ruby].include?(prev.command) && cur.command  == "gem"  ||
        %w[source ruby].include?(cur.command)  && prev.command == "gem" ||
        cur.command == "gemspec" || prev.command == "gemspec"
    end

    def normalize_entries(entries)
      groups = entries.flat_map { |e| e.entries }.group_by { |e| e.command.to_sym }
      groups[:gem] = group_gems(groups[:gem]) if groups.include?(:gem)
      groups
    end

    # Normalize group names so that :test, "test", and ['test'] are treated the same
    def group_name_option(options, key)
      val = options[key]

      if val.is_a?(Array)
        val.map!(&:to_sym)
        val.sort!
        val = val[0] if val.one?
      end

      val.respond_to?(:to_sym) ? val.to_sym : val
    end

    def normalize_groups(gems)
      gems.each do |gem|
        next unless gem.options.include?(:groups)
        gem.options[:group] = Array(gem.options[:group]).concat(Array(gem.options.delete(:groups)))
      end
    end

    # TODO: This can use a small refactor
    # Try to build groups of gems based on the options in `keys' with a count > 1.
    def group_gems(gems)
      pos  = 0
      keys = [:group, :source, :github, :path]

      normalize_groups(gems)

      groups = {}
      groups[keys[pos]] = gems.group_by { |gem| group_name_option(gem.options, keys[pos]) }

      # Now we try to build more groups
      while (pos+=1) < keys.size
        curkey = keys[pos]
        lastkey = keys[pos-1]
        next unless groups.include?(lastkey)

        newgroup = []

        # Remove it and try another group with the hope that its count will be higher
        targets = groups[lastkey].select { |k, v| v.one? }.keys
        if targets.any?
          newgroup.concat( targets.flat_map { |k| groups[lastkey].delete(k) } )
        end

        # If nil then some (or all) of the gem directives don't have the option in lastkey set
        if groups[lastkey].include?(nil)
          newgroup.concat(groups[lastkey].delete(nil))
        end

        groups[curkey] = newgroup.group_by { |gem| gem.options[curkey] }
        groups.delete(curkey)  unless groups[curkey].any?
        groups.delete(lastkey) unless groups[lastkey].any?
      end

      # Like above but the option given by keys.last
      remaining = groups.include?(curkey) ? groups[curkey].delete(nil) : []
      remaining.concat( create_grouped_entries(groups) )
    end

    def create_grouped_entries(gems)
      gems.flat_map do |command, groups|
        groups.map do |name, contents|
          contents.each { |entry| entry.options.delete(command) }
          GroupedEntry.new(command, name, nil, @config[:order][command.to_s], contents.sort)
        end
      end
    end
  end
end
