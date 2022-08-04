require_all 'lib/helpers'

namespace :maintenance do
  desc 'Cleanup temporary files'
  task cleanup: [:environment] do
    path = FileHelper.tmp_file_dir

    if Rails.env.development?
      time_offset = 1.minute
    else
      time_offset = 3.hours
    end

    Dir.foreach(path) do |item|
      fname = "#{path}#{item}"
      next if File.directory?(fname)

      if File.mtime(fname) < DateTime.now - time_offset
        begin
          File.delete(fname)
        rescue
          puts "Failed to remove temporary file: #{fname}"
        end
      end
    end

    AuthToken.destroy_old_tokens
  end

  desc 'Export auth tokens for migration from 5.x to 6.x'
  task export_auth_tokens: [:environment] do
    User.all
        .map { |u| { token: u.auth_token, user: u.id, expiry: u.auth_token_expiry } }
        .select { |d| d[:token].present? }
        .each do |d|
      puts "AuthToken.create!(authentication_token: '#{d[:token].strip}', auth_token_expiry: DateTime.parse('#{d[:expiry]}'), user_id: '#{d[:user]}')"
    end
  end
end
