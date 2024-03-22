module Similarity
  module Entities
    class TaskSimilarityEntity < Grape::Entity
      def staff?(my_role)
        Role.teaching_staff_ids.include?(my_role.id) unless my_role.nil?
      end

      expose :id
      expose :type
      expose :flagged
      expose :pct
      expose :ready_for_viewer do |similarity, _options|
        similarity.ready_for_viewer?
      end

      expose :parts do |similarity, options|
        path = similarity.file_path
        has_resource = path.present? && File.exist?(path)

        result = [
          {
            idx: 0,
            format: if has_resource
                      similarity.type == 'MossTaskSimilarity' ? 'html' : 'pdf'
                    end,
            description: "#{similarity.student.name} (#{similarity.student.username}) - #{similarity.pct}%"
          }
        ]

        # For moss similarity, show staff other student details
        if similarity.type == 'MossTaskSimilarity' && staff?(options[:my_role])
          other_path = similarity.other_similarity&.file_path
          has_other_resource = other_path.present? && File.exist?(other_path)

          result << {
            idx: 1,
            format: has_other_resource ? 'html' : nil,
            description: "Match: #{similarity.other_student&.name} (#{similarity.other_student&.username}) - #{similarity.other_similarity&.pct}"
          }
        end

        result
      end
    end
  end
end
