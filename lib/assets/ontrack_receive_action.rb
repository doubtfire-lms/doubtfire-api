# frozen_string_literal: true

require 'yaml'

def receive(_subscriber_instance, channel, _results_publisher, delivery_info, _properties, params)
  # Do something meaningful here :)
  params = JSON.parse(params)
  puts params
  # Params will contain:
  # output_path
  # task_id
  # timestamp
  # new_status: String. Can be any of the following:
  #   discuss or d	The student has completed work to a satisfactory standard and you will discuss the work with them at the next tutorial.
  #   demonstrate or demo	The same as discuss, but a reminder for you to ask the student to show you the work in class (i.e., prove to you that the code works).
  #   fix	The student has made some errors and you will want them to make fixes to their submission, and resubmit their work for re-correction at a later date.
  #   do_not_resubmit	The student has consistently submitted the same work without making required fixes. This indicates that the student should fix the work themselves and include it in their portfolio where staff will reassess it.
  #   redo	The student has completely misunderstood what the task asked of them, or have completed unrelated files to Doubtfire. You want them to start the task again from scratch.
  #   fail	The student has failed this task and will no longer have any more attempts at uploading further work. Use this sparingly.
  #   comp Complete

  if params['output_path'].nil?
    puts 'PARAM `output_path` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  if params['timestamp'].nil?
    puts 'PARAM `timestamp` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  if params['task_id'].nil?
    puts 'PARAM `task_id` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  output_path = params['output_path']
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
    # Create task comment
    comment = task.add_or_update_assessment_comment(yaml_file['message'])
    unless comment.nil?
      puts 'Created or updated task assessment_comment'
    else
      puts 'Task assessment_comment failed to be created or updated'
    end
  end

  if !yaml_file['new_status'].nil? && !yaml_file['new_status'].strip.empty?
    # if this submission is latest and no other submission exists, then:
    # Change task status
  end
  channel.ack(delivery_info.delivery_tag)
end
