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
      # Always separate blocks by a empty line. Blocks have entries > 1
      # Keep non block source and ruby calls grouped, but separate them from gem calls
      prev.entries.size > 1 || cur.entries.size > 1 ||
        %w[source ruby].include?(prev.command) && cur.command == "gem"
    end

    def normalize_entries(entries)
      propagate_options(entries)
      groups = entries.flat_map { |e| e.entries }.group_by { |e| e.command.to_sym }
      groups[:gem] = group_gems(groups[:gem]) if groups.include?(:gem)
      groups
    end

    def propagate_options(entries)
      entries.each do |entry|
        entry.each do |e|
          if entry.entries.size > 1
            # TODO: don't override e's keys with entry's
            e.options.merge!(entry.options)
            e.options[entry.command.to_sym] = entry.argv.one? ? entry.argv.first : entry.argv
          end
        end
      end
    end

    # TODO: This can use a small refactor
    def group_gems(gems)
      pos  = 0
      keys = [:group, :source, :github, :path]

      groups = {}
      groups[keys[pos]] = gems.group_by { |gem| gem.options[keys[pos]] }

      while (pos+=1) < keys.size
        curkey = keys[pos]
        lastkey = keys[pos-1]
        next unless groups.include?(lastkey)

        newgroup = []

        # If there's only one try another group with the hope of gaining more
        targets = groups[lastkey].select { |k, v| v.one? }.keys
        if targets.any?
          newgroup.concat( targets.flat_map { |k| groups[lastkey].delete(k) } )
        end

        if groups[lastkey].include?(nil)
          newgroup.concat(groups[lastkey].delete(nil))
        end

        groups[curkey] = newgroup.group_by { |gem| gem.options[curkey] }
        groups.delete(curkey)  unless groups[curkey].any?
        groups.delete(lastkey) unless groups[lastkey].any?
      end

      remaining = groups.include?(curkey) ? groups[curkey].delete(nil) : []
      remaining.concat( create_entries(groups) )
    end

    def create_entries(gems)
      gems.flat_map do |command, groups|
        groups.map do |name, contents|
          contents.each { |entry| entry.options.delete(command) }
          GroupedEntry.new(command, name, nil, @config[:order][command], contents.sort)
        end
      end
    end
  end
end
