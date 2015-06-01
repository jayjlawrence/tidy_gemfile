# TidyGemfile

`Gemfile` :shower:

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
~ >tg Gemfile
source "https://rubygems.org"

gem "airbrake"
gem "aws-s3", :require => "aws/s3"
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

1. Comments are discarded; for now, consider this additional tidying
1. Some Bundler DSL directives and arguments may cause problems -I didn't read Ruby's BNF, just a bit of `Ripper` output

Hoping to fix these at some point...

## Usage

...

## Author

Skye Shaw [sshaw AT gmail.com]

## License

Copyright © 2015 Skye Shaw. Released under the MIT License: www.opensource.org/licenses/MIT.
