module Similarity
  module Entities
    class TaskSimilarityEntity < Grape::Entity

      expose :id
      expose :type
      expose :flagged
      expose :pct
      expose :ready_for_viewer do |similarity, _options|
        similarity.ready_for_viewer?
      end

      expose :parts do |similarity|
        path = similarity.file_path
        has_resource = path.present? && File.exist?(path)

        result = [
          {
            idx: 0,
            format: if has_resource
                      similarity.type == 'JplagTaskSimilarity' ? 'html' : 'pdf'
                    end,
            description: "#{similarity.other_student.name} (#{similarity.other_student.username}) - #{similarity.pct}% similarity"
          }
        ]

        result
      end
    end
  end
end
