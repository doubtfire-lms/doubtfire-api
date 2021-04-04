require 'test_helper'

module TestHelpers
  #
  # JSON Helpers
  #
  module TestFileHelper
    module_function

    def test_file_path(filename)
      Rails.root.join('test_files', filename)
    end

    def with_files( files, hash )
      files.each_with_index do | file, idx |
        hash[ "file#{idx}".to_sym ] = Rack::Test::UploadedFile.new(Rails.root.join(file[:path]), file[:type])
      end
      hash
    end

    def with_file(path, type, hash)
      with_files( [ {path: path, type: type} ], hash)
    end

    def upload_file_csv(path)
      Rack::Test::UploadedFile.new(Rails.root.join(path))
    end

    def upload_file(path, type)
      Rack::Test::UploadedFile.new(Rails.root.join(path), type)
    end

  end
end
