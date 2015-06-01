require "tidy_gemfile/version"
require "tidy_gemfile/parser"
require "tidy_gemfile/printer"
require "tidy_gemfile/entries"

module TidyGemfile
  Error = Class.new(StandardError)
  ParseError = Class.new(Error)
end
