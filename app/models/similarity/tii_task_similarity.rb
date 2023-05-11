# frozen_string_literal: true

class TiiTaskSimilarity < TaskSimilarity
  belongs_to :tii_submission

  delegate :similarity_pdf_path, to: :tii_submission
end
