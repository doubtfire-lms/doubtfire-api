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

    def with_files(files, hash)
      files.each_with_index do |file, idx|
        hash[:"file#{idx}"] = Rack::Test::UploadedFile.new(Rails.root.join(file[:path]), file[:type])
      end
      hash
    end

    def with_file(path, type, hash)
      with_files([{ path: path, type: type }], hash)
    end

    def upload_file_csv(path)
      Rack::Test::UploadedFile.new(Rails.root.join(path))
    end

    def upload_file(path, type)
      Rack::Test::UploadedFile.new(Rails.root.join(path), type)
    end

    def archive_submission_with_pdf_fixture(task)
      return false unless task.compress_new_to_done

      FileUtils.cp(test_file_path('unit_files/sample-student-submission.pdf'), task.final_pdf_path)
      true
    end
  end
end
