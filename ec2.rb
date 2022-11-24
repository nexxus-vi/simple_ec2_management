begin
  require 'aws-sdk-ec2'
  require 'docopt'
rescue LoadError => e
  puts("#{e.message}\nPlease run 'bundle install' to install missing gems") || return
end

doc = <<DOCOPT
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
    --dry-run       Runs the program in test mode to check permissions without actually making the request.
    --verbose       Verbose output
    -v, --version   Show version.
DOCOPT

begin
  @args = Docopt.docopt(doc, version: '1.1.4')
rescue Docopt::Exit => e
  puts e.message
  exit
end

begin
  @client = Aws::EC2::Client.new
  @resource = Aws::EC2::Resource.new(client: @client)
rescue ArgumentError => e
  puts("Error: #{e.message}") || return
end

def find_ec2_by(instance_id)
  ec2 = @resource.instances.find { |i| i.instance_id == instance_id }
  puts("No instance found with id: #{instance_id}") || return if ec2.nil?
  ec2
rescue => e
  exception_handler(e)
end

def print(ec2)
  verbose_output = @args['--verbose']

  puts "Instances: #{ec2.count}"
  ec2.each.with_index(1) do |instance, i|
    instance_name = instance.tags.find { |t| break t[:value] if t[:key] == 'Name' }
    is_running = (instance.state.name == 'running')
    state_reason = instance.state_reason.code unless instance.state_reason.nil?

    puts '~' * 50
    puts "##{i}"
    puts "Instance ID:               #{instance.instance_id}"
    puts "Name:                      #{instance_name}"
    puts is_running ? "State:                     #{instance.state.name.upcase}" : "State:                     #{instance.state.name.upcase} - Reason: #{state_reason}"
    puts "Private IP address:        #{instance.private_ip_address}"

    if verbose_output || @args['describe']
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
      puts 'Security groups:'
      instance.security_groups.each do |e|
        puts "                           GroupName = #{e[:group_name]}, GroupID = #{e[:group_id]}"
      end
    end
  end
rescue => e
  exception_handler(e)
end

def exception_handler(e)
  case e
  when Aws::EC2::Errors::DryRunOperation
    puts("Checking permissions to perform this operation: #{e.message}") || return
  when Aws::EC2::Errors::UnauthorizedOperation
    puts("Error executing action: #{e.message}") || return
  when StandardError
    puts("Error requesting action: #{e.message}") || return
  end
end

def start_instance
  unless @args['--dry-run']
    case @ec2.state.name
    when 'pending'
      puts('Error starting instance: the instance is pending. Try again later.') || return
    when 'running'
      puts('The instance is already running.') || return
    when 'terminated'
      puts('Error starting instance: the instance is terminated, so you cannot start it.') || return
    end
  end

  @client.start_instances(instance_ids: [@ec2.instance_id], dry_run: @args['--dry-run'])
  @client.wait_until(:instance_running, instance_ids: [@ec2.instance_id])
  puts 'Instance started successfully.'
rescue => e
  exception_handler(e)
end

def stop_instance
  unless @args['--dry-run']
    case @ec2.state.name
    when 'stopping'
      puts('The instance is already stopping.') || return
    when 'stopped'
      puts('The instance is already stopped.') || return
    when 'terminated'
      puts('Error stopping instance: the instance is terminated, so you cannot stop it.') || return
    end
  end

  @client.stop_instances(instance_ids: [@ec2.instance_id], dry_run: @args['--dry-run'])
  @client.wait_until(:instance_stopped, instance_ids: [@ec2.instance_id])
  puts 'Instance stopped successfully.'
rescue => e
  exception_handler(e)
end

def reboot_instance
  unless @args['--dry-run']
    if @ec2.state.name == 'terminated'
      puts('Error requesting reboot: the instance is already terminated.') || return
    end
  end

  @client.reboot_instances(instance_ids: [@ec2.instance_id], dry_run: @args['--dry-run'])
  puts 'Reboot request sent.'
rescue => e
  exception_handler(e)
end

def terminate_instance
  unless @args['--dry-run']
    if @ec2.state.name == 'terminated'
      puts('The instance is already terminated.') || return
    end
  end

  @client.terminate_instances(instance_ids: [@ec2.instance_id], dry_run: @args['--dry-run'])
  @client.wait_until(:instance_terminated, instance_ids: [@ec2.instance_id])
  puts 'Instance terminated successfully.'
rescue => e
  exception_handler(e)
end

def execute_action(action_name)
  puts "Attempting to #{action_name} instance #{@ec2.instance_id}, this might take a few minutes..."
  send(:"#{action_name}_instance")
end

@ec2 = @args['<instance_id>'].nil? ? @resource.instances : find_ec2_by(@args['<instance_id>'])
return "No instances found" unless @ec2

case
when @args['list']
  filter_state = @args['--running'] || @args['--stopped']
  if filter_state
    state_name = @args['--running'] ? 'running' : 'stopped'
    @ec2 = @ec2.select {|i| i.state.name == state_name}
  end
  print(@ec2)
when @args['describe']
  print([@ec2])
when @args['start']
  execute_action('start')
when @args['stop']
  execute_action('stop')
when @args['reboot']
  execute_action('reboot')
when @args['terminate']
  execute_action('terminate')
end
