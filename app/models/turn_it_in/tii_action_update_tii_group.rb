# freeze_string_literal: true

# Track updating of a group (assignment / task definition) in TurnItIn
class TiiActionUpdateTiiGroup < TiiAction
  def description
    "Update assessment for #{entity.detailed_name} in #{entity.unit.code}"
  end

  def run
    # Generate id but do not save until put is complete
    entity.tii_group_id = SecureRandom.uuid unless entity.tii_group_id.present?

    data = TCAClient::AggregateGroup.new(
      id: entity.tii_group_id,
      name: entity.detailed_name,
      type: 'ASSIGNMENT',
      group_context: TurnItIn.create_or_get_group_context(entity.unit),
      due_date: entity.due_date,
      report_generation: 'IMMEDIATELY_AND_DUE_DATE'
    )

    error_code = [
      { code: 404, message: 'Assessment not found in turn it in' }
    ]

    exec_tca_call "create or update group #{entity.tii_group_id} for task definition #{entity.id}", error_code do
      TCAClient::GroupsApi.new.groups_group_id_put(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        entity.tii_group_id,
        data
      )

      # Send attachments to TII
      entity.send_group_attachments_to_tii if params.key?("add_group_attachment") && params["add_group_attachment"]

      # Save the task definition and complete if save succeeds
      self.complete = entity.save
      params = {} if self.complete
      # Save action
      save
    end
  end
end
