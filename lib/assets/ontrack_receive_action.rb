# frozen_string_literal: true

require 'yaml'

def receive(_subscriber_instance, channel, _results_publisher, delivery_info, _properties, params)
  # Do something meaningful here :)
  params = JSON.parse(params)
  puts params
  # Params will contain:
  # task_id
  # timestamp

  if params['timestamp'].nil?
    puts 'PARAM `timestamp` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  if params['task_id'].nil?
    puts 'PARAM `task_id` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  timestamp = params['timestamp']
  task_id = params['task_id']

  task = Task.find(task_id)

  unless task
    puts "No task found for id: #{task_id}"
    return channel.ack(delivery_info.delivery_tag)
  end

  output_path = PortfolioEvidence.task_submission_identifier_path_with_timestamp(:done, task, timestamp)

  yaml_path = "#{output_path}/output.yaml"

  unless File.exist? yaml_path
    puts "File #{yaml_path} doesn't exist"
    return channel.ack(delivery_info.delivery_tag)
  end

  yaml_file = YAML.load_file(yaml_path).with_indifferent_access
  if !yaml_file['message'].nil? && !yaml_file['message'].strip.empty?
    # TODO: if this submission is latest and no other submission exists, then:
    # Create task comment
    comment = task.add_or_update_assessment_comment(yaml_file['message'])
    unless comment.nil?
      puts 'Created or updated task assessment_comment'
    else
      puts 'Task assessment_comment failed to be created or updated'
    end
  else
    puts 'YAML file doesn\'t contain field `message`'
  end

  # TODO: Work with Andrew to figure the protocol for this.
  # if !yaml_file['new_status'].nil? && !yaml_file['new_status'].strip.empty?
  #   # if this submission is latest and no other submission exists, then:
  #   # Change task status

  #   latest_timestamp = FileHelper.latest_submission_timestamp_entry_in_dir

  #   if timestamp < latest_timestamp

  #   end

  #   new_status = TaskStatus.status_for_name(yaml_file['new_status'])
  #   if new_status
  #     task.task_status = new_status
  #   else
  #     puts "Invalid status message #{yaml_file['new_status']}"
  #   end
  # else
  #   puts 'YAML file doesn\'t contain field `new_status`'
  # end

  channel.ack(delivery_info.delivery_tag)
end
