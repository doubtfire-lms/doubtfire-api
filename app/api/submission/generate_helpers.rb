# zipping files
require 'zip'

module Submission::GenerateHelpers
  #
  # Scoops out a files array from the params provided
  #
  def scoop_files(params, upload_reqs)
    files = params.reject { |key| !(key =~ /^file\d+$/) }

    error!({ error: 'Upload requirements mismatch with files provided' }, 403) if files.length != upload_reqs.length
    #
    # Pair the name and type from upload_requirements to each file
    #
    upload_reqs.each do |detail|
      key = detail['key']
      next unless files.key?(key) && files[key].is_a?(Hash)

      files[key][:id]   = files[key]['name']
      files[key][:name] = detail['name']
      files[key][:type] = detail['type']
    end

    # File didn't get assigned an id above, then reject it since there was a mismatch
    files = files.reject { |_key, file| file[:id].nil? }
    error!({ error: 'Upload requirements mismatch with files provided' }, 403) if files.length != upload_reqs.length

    # Kill the kvp
    files.map { |_k, v| v }
  end

  # module_function :combine_to_pdf
  module_function :scoop_files
end
