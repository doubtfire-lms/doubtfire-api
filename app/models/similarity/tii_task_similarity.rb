# frozen_string_literal: true

class TiiTaskSimilarity < TaskSimilarity
  belongs_to :tii_submission

  delegate :similarity_pdf_path, :create_viewer_url, to: :tii_submission

  def file_path
    tii_submission.similarity_pdf_path
  end

  def ready_for_viewer?
    tii_submission.present? && tii_submission.ready_for_viewer?
  end

end
