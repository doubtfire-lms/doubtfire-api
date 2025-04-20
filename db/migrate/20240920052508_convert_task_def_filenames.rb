class ConvertTaskDefFilenames < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:task_definitions, :new_column_name)
      add_column :task_definitions, :new_column_name, :string
    end

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

class AddAuthTokenType < ActiveRecord::Migration[7.1]
  def change
    add_column :auth_tokens, :token_type, :integer, null: false, default: 0
    add_index :auth_tokens, :token_type
  end
end
