# ![](https://raw.github.com/aptible/straptible/master/lib/straptible/rails/templates/public.api/icon-60px.png) Aptible CLI

[![Gem Version](https://badge.fury.io/rb/aptible-cli.png)](https://rubygems.org/gems/aptible-cli)
[![Build Status](https://travis-ci.org/aptible/aptible-cli.png?branch=master)](https://travis-ci.org/aptible/aptible-cli)
[![Dependency Status](https://gemnasium.com/aptible/aptible-cli.png)](https://gemnasium.com/aptible/aptible-cli)
[![codecov](https://codecov.io/gh/aptible/aptible-cli/branch/master/graph/badge.svg)](https://codecov.io/gh/aptible/aptible-cli)
[![Roadmap](https://badge.waffle.io/aptible/aptible-cli.svg?label=ready&title=roadmap)](http://waffle.io/aptible/aptible-cli)

Command-line interface for Aptible services.

## Installation

**NOTE: To install the `aptible` tool as a system-level binary, Aptible
recommends you install the
[Aptible Toolbelt](https://support.aptible.com/toolbelt/)**, which is faster
and more robust.

Add the following line to your application's Gemfile.

    gem 'aptible-cli'

And then run `bundle install`.


## Usage

From `aptible help`:

<!-- BEGIN USAGE -->
```
Commands:
  aptible apps                                                                                                                       # List all applications
  aptible apps:create HANDLE                                                                                                         # Create a new application
  aptible apps:deprovision                                                                                                           # Deprovision an app
  aptible apps:scale SERVICE [--container-count COUNT] [--container-size SIZE_MB]                                                    # Scale a service
  aptible backup:list DB_HANDLE                                                                                                      # List backups for a database
  aptible backup:restore BACKUP_ID [--environment ENVIRONMENT_HANDLE] [--handle HANDLE] [--container-size SIZE_MB] [--size SIZE_GB]  # Restore a backup
  aptible config                                                                                                                     # Print an app's current configuration
  aptible config:add [VAR1=VAL1] [VAR2=VAL2] [...]                                                                                   # Add an ENV variable to an app
  aptible config:rm [VAR1] [VAR2] [...]                                                                                              # Remove an ENV variable from an app
  aptible config:set [VAR1=VAL1] [VAR2=VAL2] [...]                                                                                   # Add an ENV variable to an app
  aptible config:unset [VAR1] [VAR2] [...]                                                                                           # Remove an ENV variable from an app
  aptible db:backup HANDLE                                                                                                           # Backup a database
  aptible db:clone SOURCE DEST                                                                                                       # Clone a database to create a new one
  aptible db:create HANDLE [--type TYPE] [--version VERSION] [--container-size SIZE_MB] [--size SIZE_GB]                             # Create a new database
  aptible db:deprovision HANDLE                                                                                                      # Deprovision a database
  aptible db:dump HANDLE [pg_dump options]                                                                                           # Dump a remote database to file
  aptible db:execute HANDLE SQL_FILE [--on-error-stop]                                                                               # Executes sql against a database
  aptible db:list                                                                                                                    # List all databases
  aptible db:reload HANDLE                                                                                                           # Reload a database
  aptible db:replicate HANDLE REPLICA_HANDLE [--container-size SIZE_MB] [--size SIZE_GB]                                             # Create a replica/follower of a database
  aptible db:restart HANDLE [--container-size SIZE_MB] [--size SIZE_GB]                                                              # Restart a database
  aptible db:tunnel HANDLE                                                                                                           # Create a local tunnel to a database
  aptible db:url HANDLE                                                                                                              # Display a database URL
  aptible db:versions                                                                                                                # List available database versions
  aptible deploy [OPTIONS] [VAR1=VAL1] [VAR2=VAL2] [...]                                                                             # Deploy an app
  aptible domains                                                                                                                    # Print an app's current virtual domains - DEPRECATED
  aptible endpoints:database:create DATABASE                                                                                         # Create a Database Endpoint
  aptible endpoints:deprovision [--app APP | --database DATABASE] ENDPOINT_HOSTNAME                                                  # Deprovision an App or Database Endpoint
  aptible endpoints:https:create [--app APP] SERVICE                                                                                 # Create an App HTTPS Endpoint
  aptible endpoints:https:modify [--app APP] ENDPOINT_HOSTNAME                                                                       # Modify an App HTTPS Endpoint
  aptible endpoints:list [--app APP | --database DATABASE]                                                                           # List Endpoints for an App or Database
  aptible endpoints:renew [--app APP] ENDPOINT_HOSTNAME                                                                              # Renew an App Managed TLS Endpoint
  aptible endpoints:tcp:create [--app APP] SERVICE                                                                                   # Create an App TCP Endpoint
  aptible endpoints:tcp:modify [--app APP] ENDPOINT_HOSTNAME                                                                         # Modify an App TCP Endpoint
  aptible endpoints:tls:create [--app APP] SERVICE                                                                                   # Create an App TLS Endpoint
  aptible endpoints:tls:modify [--app APP] ENDPOINT_HOSTNAME                                                                         # Modify an App TLS Endpoint
  aptible help [COMMAND]                                                                                                             # Describe available commands or one specific command
  aptible login                                                                                                                      # Log in to Aptible
  aptible logs [--app APP | --database DATABASE]                                                                                     # Follows logs from a running app or database
  aptible operation:cancel OPERATION_ID                                                                                              # Cancel a running operation
  aptible ps                                                                                                                         # Display running processes for an app - DEPRECATED
  aptible rebuild                                                                                                                    # Rebuild an app, and restart its services
  aptible restart                                                                                                                    # Restart all services associated with an app
  aptible services                                                                                                                   # List Services for an App
  aptible ssh [COMMAND]                                                                                                              # Run a command against an app
  aptible version                                                                                                                    # Print Aptible CLI version
```
<!-- END USAGE -->

### Output Format

By default, the Aptible CLI outputs data as unstructured text, designed for human consumption.

If you need to parse the output in another program, set the `APTIBLE_OUTPUT_FORMAT` environment variable to `json` when calling the Aptible CLI for JSON output.

The default format is `text`.

## Contributing

1. Fork the project.
1. Commit your changes, with specs.
1. Ensure that your code passes specs (`rake spec`) and meets Aptible's Ruby style guide (`rake rubocop`).
1. If you add a command, sync this README (`bundle exec script/sync-readme-usage`).
1. Create a new pull request on GitHub.

## Contributors

* Frank Macreery ([@fancyremarker](https://github.com/fancyremarker))
* Graham Melcher ([@melcher](https://github.com/melcher))
* Pete Browne ([@petebrowne](https://github.com/petebrowne))
* Rich Humphrey ([@rdh](https://github.com/rdh))
* Daniel Levenson ([@dleve123](https://github.com/dleve123))
* Ryan Aipperspach ([@ryanaip](https://github.com/ryanaip))
* Chas Ballew ([@chasballew](https://github.com/chasballew))
* Chet Bortz ([@cbortz](https://github.com/cbortz))

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2019 [Aptible](https://www.aptible.com) and contributors.
