require 'test_helper'

module TestHelpers
  #
  # JSON Helpers
  #
  module TestFileHelper
    module_function

    def with_files( files, hash )
      files.each_with_index do | file, idx |
        hash[ "file#{idx}".to_sym ] = Rack::Test::UploadedFile.new(Rails.root.join(file[:path]), file[:type])
      end
      hash
    end

    def with_file(path, type, hash)
      with_files( [ {path: path, type: type} ], hash)
    end
  end
end
