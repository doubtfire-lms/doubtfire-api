# freeze_string_literal: true

# Fetch the eula version and html from turn it in
class TiiActionGetViewUrl < TiiAction
  delegate :status_sym, :status, :submission_id, :submitted_by_user, :task, :idx, :similarity_pdf_id, :similarity_pdf_path, :filename, to: :entity

  def description
    "Get viewer url for #{self.filename} of #{self.task.student.username} from #{self.task.task_definition.abbreviation}"
  end

  def run
    result = fetch_view_url
    if result.present?
      self.complete = true
      result
    end
  end

  # Connect to tii to get the latest eula details.
  def fetch_view_url
    view_user_id = params['viewer_user_id'] || params[:viewer_user_id]
    view_user = User.find(view_user_id)

    exec_tca_call 'fetch view url' do
      data = TCAClient::SimilarityViewerUrlSettings.new(
        viewer_user_id: view_user.username,
        locale: 'en-US',
        viewer_default_permission_set: "INSTRUCTOR"
      )

      # Add eula acceptance details to viewer, if required
      if view_user.accepted_tii_eula? && !view_user.eula_accepted_and_confirmed?
        data.eula = TCAClient::Eula.new(
          language: 'en-us',
          accepted_timestamp: submitted_by_user.tii_eula_date || DateTime.now,
          version: submitted_by_user.tii_eula_version || TurnItIn.eula_version
        )
      end

      api_instance = TCAClient::SimilarityApi.new
      report = api_instance.get_similarity_report_url(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        submission_id,
        data
      )

      # return the eula
      report.viewer_url
    end
  end
end
