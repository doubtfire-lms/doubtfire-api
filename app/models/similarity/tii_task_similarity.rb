# frozen_string_literal: true

class TiiTaskSimilarity < TaskSimilarity
  belongs_to :tii_submission

  delegate :similarity_pdf_path, :create_viewer_url, to: :tii_submission
end
