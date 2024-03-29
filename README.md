**Simple EC2 Management Script**

This is a simple script to manage existing EC2 instances on AWS. 

**Requirements**

`Ruby >= 2.3` & `Bundler 2.2.32`

You have to set up your AWS credentials as described in the [official documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html)

Alternatively you can initialize `@client` with `access_key_id`, `secret_access_key` and `region`:

`@client = Aws::EC2::Client.new(access_key_id: 'ACCESSKEY', secret_access_key: 'SECRET', region: 'eu-north-1')`

**Install gems**

`gem install bundler:2.2.32`

`bundle install`

**Usage**

```
$ ruby ec2.rb -h
Simple EC2 Management.

  Usage:
    ec2 list [--verbose] [-r | -s]
    ec2 describe <instance_id>
    ec2 (start | stop | reboot | terminate) <instance_id> [--dry-run]
    ec2 -h | --help
    ec2 --version

  Options:
    -h --help       Show this screen.
    -r, --running   Show only running instances.
    -s, --stopped   Show only stopped instances.
    --dry-run       Checks whether you have the required permissions for the action, without actually making the request.
    --verbose       Verbose output
    -v, --version   Show version.
```

***Example usage:***

```
$ ruby ec2.rb list
Instances: 5
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#1
Instance ID:               i-123456789
Name:                      instance_name
State:                     STOPPED - Reason: Client.UserInitiatedShutdown
Private IP address:        0.0.0.0
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
...

$ ruby ec2.rb start i-123456789 --dry-run
Attempting to start instance 'i-123456789' (this might take a few minutes)...
Check permissions to perform this operation: Request would have succeeded, but DryRun flag is set.
```
