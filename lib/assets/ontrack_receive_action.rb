# frozen_string_literal: true

require 'yaml'

def receive(_subscriber_instance, channel, _results_publisher, delivery_info, _properties, params)
  params = JSON.parse(params)
  puts params
  # Params will contain:
  # task_id
  # timestamp
  # overseer assessment id

  if params['timestamp'].nil?
    puts 'PARAM `timestamp` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  if params['task_id'].nil?
    puts 'PARAM `task_id` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  if params['overseer_assessment_id'].nil?
    puts 'PARAM `overseer_assessment_id` is required'
    return channel.ack(delivery_info.delivery_tag)
  end

  timestamp = params['timestamp']
  i_timestamp = timestamp.to_i

  if i_timestamp == 0
    puts "Invalid timestamp: #{timestamp}"
    return channel.ack(delivery_info.delivery_tag)
  end

  task_id = params['task_id']
  task = Task.find(task_id)

  unless task.present?
    puts "No task found for id: #{task_id}"
    return channel.ack(delivery_info.delivery_tag)
  end

  overseer_assessment_id = params['overseer_assessment_id']
  overseer_assessment = OverseerAssessment.find(overseer_assessment_id)

  unless overseer_assessment.present?
    puts "No overseer_assessment found for id: #{overseer_assessment_id}"
    return channel.ack(delivery_info.delivery_tag)
  end

  overseer_assessment.status = 3

  output_path = FileHelper.task_submission_identifier_path_with_timestamp(:done, task, timestamp)
  yaml_path = "#{output_path}/output.yaml"

  if File.exist? yaml_path
    yaml_file = YAML.load_file(yaml_path).with_indifferent_access

    task_latest_done_assessment = OverseerAssessment.where(task_id: task_id, status: 3).order(:submission_timestamp).last
    i_latest_done_timestamp = task_latest_done_assessment.submission_timestamp.to_i if task_latest_done_assessment.present?

    comment_txt = ''
    if !yaml_file['build_message'].nil? && !yaml_file['build_message'].strip.empty?
      comment_txt += yaml_file['build_message']
    end
    if !yaml_file['run_message'].nil? && !yaml_file['run_message'].strip.empty?
      comment_txt += "\n\n" unless comment_txt.empty?
      comment_txt += yaml_file['run_message']
    end
    if comment_txt.present?
      # If no later submission with `status = done` exists, then create or update task comment
      if i_latest_done_timestamp.nil? || i_timestamp > i_latest_done_timestamp
        comment = task.add_or_update_assessment_comment(comment_txt)
        unless comment.nil?
          puts 'Created or updated task assessment_comment'
        else
          puts 'Task assessment_comment failed to be created or updated'
        end
      end
    else
      puts 'YAML file doesn\'t contain field `build_message` or `run_message`'
    end

    if yaml_file['new_status'].present?
      new_status = TaskStatus.status_for_name(yaml_file['new_status'])
      overseer_assessment.result_task_status = new_status ? new_status.status_key : 'invalid_status'

      # If no later submission with `status = done` exists, then change task status
      if i_latest_done_timestamp.nil? || i_timestamp > i_latest_done_timestamp
        if new_status
          task.task_status = new_status
          task.save
        else
          puts "Invalid status message #{yaml_file['new_status']}"
        end
      end
    else
      puts 'YAML file doesn\'t contain field `new_status`'
      overseer_assessment.result_task_status = task.status
    end
  else
    puts "File #{yaml_path} doesn't exist"
  end
rescue StandardError => e
  puts e
ensure
  overseer_assessment.save! unless overseer_assessment.nil?
  channel.ack(delivery_info.delivery_tag)
end
