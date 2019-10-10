require "test_helper"

class FileHelperTest < ActiveSupport::TestCase
  def test_convert_use
    in_file = 'test_files/submissions/unbelievable.gif'

    Dir.mktmpdir do |dir|
      dir = 'test_files/submissions/'
      dest_file = "#{dir}#{File.basename(in_file, ".*")}.jpg"
      FileHelper.compress_image_to_dest in_file, dest_file, true
      puts dest_file
      assert File.exists? dest_file
    end
  end
end
