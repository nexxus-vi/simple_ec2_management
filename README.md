**Simple EC2 Manager Script**

This is a simple script to manage existing EC2 instances on AWS. 

**Requirements**

`Ruby >= 2.3`

You have to set up your AWS credentials as described in the [official documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html)

**Install gems**

`bundle install`

**Usage**

```
  ec2 list [--verbose] [-r | -s]
  ec2 describe <instance>
  ec2 (start | stop | reboot | terminate) <instance> [--dry-run]
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
Error starting instance: Request would have succeeded, but DryRun flag is set.
Could not start instance.
```