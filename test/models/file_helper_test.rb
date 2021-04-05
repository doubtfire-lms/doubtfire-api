require "test_helper"

class FileHelperTest < ActiveSupport::TestCase
  def test_convert_use_with_gif
    in_file = "#{Rails.root}/test_files/submissions/unbelievable.gif"

    Dir.mktmpdir do |dir|
      dest_file = "#{dir}#{File.basename(in_file, ".*")}.jpg"
      assert FileHelper.compress_image_to_dest(in_file, dest_file, true)
      assert File.exists? dest_file
    end
  end
end
