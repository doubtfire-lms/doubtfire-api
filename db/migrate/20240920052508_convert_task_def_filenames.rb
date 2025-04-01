class ConvertTaskDefFilenames < ActiveRecord::Migration[7.1]

  # Check filenames in the upload requirements for each task definition
  # and replace any invalid characters using sanitize filename
  def change
    TaskDefinition.find_in_batches do |group|
      group.each do |task_def|
        next if task_def.valid?

        upload_req = task_def.upload_requirements

        change = false
        upload_req.each do |req|
          unless req['name'].match?(/^[a-zA-Z0-9_\- \.]+$/)
            req['name'] = FileHelper.sanitized_filename(req['name'])
            change = true
          end

          if req['name'].blank?
            req['name'] = 'file'
            change = true
          end
        end

        unless change && task_def.valid? && task_def.save
          puts "Remaining issue with task definition #{task_def.id}"
        end
        puts '.'
      end
    end
  end
end
