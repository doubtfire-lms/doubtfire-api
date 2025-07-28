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

      expose :other_task, safe: true
      expose :other_student, safe: true

      expose :parts do |similarity, options|
        path = similarity.file_path
        has_resource = path.present? && File.exist?(path)

        result = []
        case similarity.type
        when 'JplagTaskSimilarity'
          # We display just the "Other student" for JPlag similarities
          # JPlag report viewer will show both students side by side
          result <<
            {
              idx: 0,
              format: has_resource ? 'jplag' : nil,
              description: "#{similarity.other_student&.name} (#{similarity.other_student&.username}) - #{similarity.pct}% similarity"
            }
        when 'MossTaskSimilarity'
          result <<
            {
              idx: 0,
              format: has_resource ? 'html' : nil,
              description: "#{similarity.student.name} (#{similarity.student.username}) - #{similarity.pct}% similarity"
            }

          # For moss similarity, show staff other student details
          if staff?(options[:my_role])
            other_path = similarity.other_similarity&.file_path
            has_other_resource = other_path.present? && File.exist?(other_path)
            result <<
              {
                idx: 1,
                format: has_other_resource ? 'html' : nil,
                description: "#{similarity.other_student.name} (#{similarity.other_student.username}) - #{similarity.pct}% similarity"
              }
          end

        when 'TiiTaskSimilarity'
          result <<
            {
              idx: 0,
              format: has_resource ? 'pdf' : nil,
              description: "#{similarity.pct}% similarity"
            }
        end

        result
      end
    end
  end
end
