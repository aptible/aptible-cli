# ![](https://raw.github.com/aptible/straptible/master/lib/straptible/rails/templates/public.api/icon-60px.png) Aptible CLI

[![Gem Version](https://badge.fury.io/rb/aptible-cli.png)](https://rubygems.org/gems/aptible-cli)
[![Build Status](https://travis-ci.org/aptible/aptible-cli.png?branch=master)](https://travis-ci.org/aptible/aptible-cli)
[![Dependency Status](https://gemnasium.com/aptible/aptible-cli.png)](https://gemnasium.com/aptible/aptible-cli)

[![Roadmap](https://badge.waffle.io/aptible/aptible-cli.svg?label=ready&title=roadmap)](http://waffle.io/aptible/aptible-cli)

Command-line interface for Aptible services.

## Installation

Add the following line to your application's Gemfile.

    gem 'aptible-cli'

And then run `bundle install`.

*NOTE: To install the `aptible` tool as a system-level binary, consider using the [aptible-toolbelt gem](https://github.com/aptible/aptible-toolbelt), which is performance-optimized through dependency pinning.*

## Usage

From `aptible help`:

```
Commands:
  aptible apps                        # List all applications
  aptible apps:create HANDLE          # Create a new application
  aptible apps:deprovision            # Deprovision an app
  aptible apps:scale TYPE NUMBER      # Scale app to NUMBER of instances
  aptible config                      # Print an app's current configuration
  aptible config:add                  # Add an ENV variable to an app
  aptible config:rm                   # Remove an ENV variable from an app
  aptible config:set                  # Alias for config:add
  aptible config:unset                # Alias for config:rm
  aptible db:clone SOURCE DEST        # Clone a database to create a new one
  aptible db:create HANDLE            # Create a new database
  aptible db:deprovision HANDLE       # Deprovision a database
  aptible db:dump HANDLE              # Dump a remote database to file
  aptible db:execute HANDLE SQL_FILE  # Executes sql against a database
  aptible db:list                     # List all databases
  aptible db:tunnel HANDLE            # Create a local tunnel to a database
  aptible domains                     # Print an app's current virtual domains
  aptible help [COMMAND]              # Describe available commands or one specific command
  aptible login                       # Log in to Aptible
  aptible logs                        # Follows logs from a running app
  aptible ps                          # Display running processes for an app - DEPRECATED
  aptible rebuild                     # Rebuild an app, and restart its services
  aptible restart                     # Restart all services associated with an app
  aptible ssh [COMMAND]               # Run a command against an app
  aptible version                     # Print Aptible CLI version
```

## Contributing

1. Fork the project.
1. Commit your changes, with specs.
1. Ensure that your code passes specs (`rake spec`) and meets Aptible's Ruby style guide (`rake rubocop`).
1. If you add a command, update this README with the output of `aptible help | grep -v help`.
1. Create a new pull request on GitHub.

## Contributors

* Frank Macreery ([@fancyremarker](https://github.com/fancyremarker))
* Graham Melcher ([@melcher](https://github.com/melcher))
* Pete Browne ([@petebrowne](https://github.com/petebrowne))
* Rich Humphrey ([@rdh](https://github.com/rdh))
* Daniel Levenson ([@dleve123](https://github.com/dleve123))
* Ryan Aipperspach ([@ryanaip](https://github.com/ryanaip))
* Chas Ballew ([@chasballew](https://github.com/chasballew))

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2016 [Aptible](https://www.aptible.com) and contributors.

[<img src="https://s.gravatar.com/avatar/f7790b867ae619ae0496460aa28c5861?s=60" style="border-radius: 50%;" alt="@fancyremarker" />](https://github.com/fancyremarker)
