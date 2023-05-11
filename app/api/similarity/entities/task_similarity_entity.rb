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

      expose :parts do |similarity, options|
        result = [
          {
            idx: 0,
            format: similarity.type == 'MossTaskSimilarity' ? 'html' : 'pdf',
            description: "#{similarity.student.name} (#{similarity.student.username}) - #{similarity.pct}%"
          }
        ]

        # For moss similarity, show staff other student details
        if similarity.type == 'MossTaskSimilarity' && staff?(options[:my_role])
          result << {
            idx: 1,
            format: 'html',
            description: "Match: #{similarity.other_student&.name} (#{similarity.other_student&.username}) - #{similarity.other_similarity&.pct}"
          }
        end

        result
      end
    end
  end
end
