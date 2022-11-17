require 'aws-sdk-ec2'
require "docopt"

doc = <<DOCOPT
EC2 Management.

Usage:
  ec2 list [--verbose] [-r | -s]
  ec2 describe <instance>
  ec2 (start | stop | reboot | terminate) <instance> [--dry-run]
  ec2 -h | --help
  ec2 --version

Options:
  -h --help       Show this screen.
  -r, --running   Show only running instances.
  -s, --stopped   Show only stopped instances.
  --dry-run       Runs the program in test mode to check permissions without actually making the request.
  --verbose       Verbose output
  -v, --version   Show version.
DOCOPT

begin
  args = Docopt::docopt(doc, version: '1.0.0')
rescue Docopt::Exit => e
  puts doc
  exit
end

client = Aws::EC2::Client.new
ec2_resource = Aws::EC2::Resource.new(client: client)
instances = ec2_resource.instances

def print(instances, args)
  verbose_output = args['--verbose']
  puts "Instances: #{instances.count}"
  instances.each.with_index(1) do |instance, i|
    instance_name = instance.tags.find { |t| break t[:value] if t[:key] == 'Name' }
    state_reason = instance.state_reason.code unless instance.state_reason.nil?

    puts '~' * 50
    puts  "##{i}"
    puts "Instance ID:               #{instance.instance_id}"
    puts "Name:                      #{instance_name}"
    puts args['--running'] ? "State:                     #{instance.state.name.upcase}" : "State:                     #{instance.state.name.upcase} - Reason: #{state_reason}"
    puts "Private IP address:        #{instance.private_ip_address}"

    if verbose_output || args['describe']
      puts "Instance type:             #{instance.instance_type}"
      puts "Location:                  #{instance.placement.availability_zone}"
      puts "IAM instance profile ARN:  #{instance.iam_instance_profile.arn}" unless instance.iam_instance_profile.nil?
      puts "Key name:                  #{instance.key_name}"
      puts "Launch time:               #{instance.launch_time}"
      puts "Monitoring:                #{instance.monitoring.state}"
      puts "Public IP address:         #{instance.public_ip_address}" unless instance.public_ip_address.nil?
      puts "Public DNS name:           #{instance.public_dns_name}" unless instance.public_dns_name.empty?
      puts "VPC ID:                    #{instance.vpc_id}"
      puts "Subnet ID:                 #{instance.subnet_id}"
      if instance.tags.count.positive?
        puts 'Tags:'
        instance.tags.each do |tag|
          puts "                           #{tag.key} = #{tag.value}"
        end
      end
      puts "Security groups:"
      instance.security_groups.each { |e| puts "                           Group name = #{e[:group_name]}, Group ID = #{e[:group_id]}"}
    end
  end
end

def instance_stopped?(ec2_client, args)
  instance_id = args['<instance>']
  response = ec2_client.describe_instance_status(instance_ids: [instance_id])

  if response.instance_statuses.count.positive?
    state = response.instance_statuses[0].instance_state.name
    case state
    when 'stopping'
      puts 'The instance is already stopping.'
      return true
    when 'stopped'
      puts 'The instance is already stopped.'
      return true
    when 'terminated'
      puts 'Error stopping instance: ' \
        'the instance is terminated, so you cannot stop it.'
      return false
    end
  end

  ec2_client.stop_instances(instance_ids: [instance_id], dry_run: args['--dry-run'])
  ec2_client.wait_until(:instance_stopped, instance_ids: [instance_id])
  puts 'Instance stopped.'
  return true
rescue StandardError => e
  puts "Error stopping instance: #{e.message}"
  return false
end

def instance_started?(ec2_client, args)
  instance_id = args['<instance>']
  response = ec2_client.describe_instance_status(instance_ids: [instance_id])

  if response.instance_statuses.count.positive?
    state = response.instance_statuses[0].instance_state.name
    case state
    when 'pending'
      puts 'Error starting instance: the instance is pending. Try again later.'
      return false
    when 'running'
      puts 'The instance is already running.'
      return true
    when 'terminated'
      puts 'Error starting instance: ' \
        'the instance is terminated, so you cannot start it.'
      return false
    end
  end

  ec2_client.start_instances(instance_ids: [instance_id], dry_run: args['--dry-run'])
  ec2_client.wait_until(:instance_running, instance_ids: [instance_id])
  puts 'Instance started.'
  return true
rescue StandardError => e
  puts "Error starting instance: #{e.message}"
  return false
end

def attempt_reboot(client, instance, args)
  instance_id = args['<instance>']
  if instance.state.name == 'terminated'
    puts 'Error requesting reboot: the instance is already terminated.'
  else
    client.reboot_instances(instance_ids: [instance_id], dry_run: args['--dry-run'])
    puts 'Reboot request sent.'
  end
rescue StandardError => e
  puts "Error requesting reboot: #{e.message}"
end

def attempt_termination(client, instance, args)
  instance_id = args['<instance>']
  if instance.state.name == 'terminated'
    puts 'The instance is already terminated.'
    return true
  end

  client.terminate_instances(instance_ids: [args['<instance>']], dry_run: args['--dry-run'])
  client.wait_until(:instance_terminated, instance_ids: [instance_id])
  puts 'Instance terminated.'
  return true
rescue StandardError => e
  puts "Error terminating instance: #{e.message}"
end

case
when args['list']
  if instances.count.zero?
    puts 'No instances found.'
  else
    filter_status = args['--running'] || args['--stopped']

    if filter_status
      state_name = args['--running'] ? 'running' : 'stopped'
      instances = instances.select {|i| i.state.name == state_name}
    end

    print(instances, args)
  end
when args['describe']
  instance = instances.find { |i| i.instance_id == args['<instance>'] }
  if instance.nil?
    puts "No instance found with id: #{args['<instance>']}"
  else
    print([instance], args)
  end
when args['start']
  instance = instances.find { |i| i.instance_id == args['<instance>'] }
  if instance.nil?
    puts "No instance found with id: #{args['<instance>']}"
  else
    puts "Attempting to start instance '#{args['<instance>']}' " \
    '(this might take a few minutes)...'
    unless instance_started?(client, args)
      puts 'Could not start instance.'
    end
  end
when args['stop']
  instance = instances.find { |i| i.instance_id == args['<instance>'] }
  if instance.nil?
    puts "No instance found with id: #{args['<instance>']}"
  else
    puts "Attempting to stop instance #{args['<instance>']} " \
    '(this might take a few minutes)...'
    unless instance_stopped?(client, args)
      puts 'Could not stop instance.'
    end
  end
when args['reboot']
  instance = instances.find { |i| i.instance_id == args['<instance>'] }
  if instance.nil?
    puts "No instance found with id: #{args['<instance>']}"
  else
    puts "Attempting to reboot instance #{args['<instance>']} " \
    '(this might take a few minutes)...'
    attempt_reboot(client, instance, args)
  end
when args['terminate']
  instance = instances.find { |i| i.instance_id == args['<instance>'] }
  if instance.nil?
    puts "No instance found with id: #{args['<instance>']}"
  else
    puts "Attempting to terminate instance #{args['<instance>']} " \
    '(this might take a few minutes)...'
    unless attempt_termination(client, instance, args)
      puts 'Could not terminate instance.'
    end
  end
end
