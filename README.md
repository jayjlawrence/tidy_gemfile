# TidyGemfile

`Gemfile` :shower:

Your Gemfile is a mess and TidyGemfile is here to clean it up.

## Overview

Before TidyGemfile:

```
~ >cat Gemfile
source "https://rubygems.org"

gem 'fabrication', '2.10.0', group: 'test'
gem "capybara", :group => "test"
gem "capybara-screenshot", :group => "test"

group 'development' do
  gem 'sextant'
  gem "rails-erd"
end

gem "ddex"
gem "aws-s3", require: 'aws/s3'
gem "database_cleaner", :group => "development"
gem "airbrake"
gem 'spring',        group: "development"
```

After:

```
~ >tg -p Gemfile
source "https://rubygems.org"

gem "airbrake"
gem "aws-s3", require: "aws/s3"
gem "ddex"

group "development" do
  gem "database_cleaner"
  gem "rails-erd"
  gem "sextant"
  gem "spring"
end

group "test" do
  gem "capybara"
  gem "capybara-screenshot"
  gem "fabrication", "2.10.0"
end
```

### Caveats

1. WIP
1. Comments are discarded; for now, consider this additional tidying
1. Some Bundler DSL directives and arguments may cause problems -I didn't read Ruby's BNF, just a bit of `Ripper` output

Hoping to fix these at some point...

## Usage

```
usage: tg [options] Gemfile
    -h, --hash-style STYLE           Hash style to use
    -p, --print                      Print formatted Gemfile on stdout instead of overwriting it
    -q, --quote-style STYLE          Quote style to use
    -o, --order gem=1[,source=2,...] Order of Gemfile directives
```

## Author

Skye Shaw [sshaw AT gmail.com]

## License

Copyright © 2015 Skye Shaw. Released under [the MIT License](http://www.opensource.org/licenses/MIT).
