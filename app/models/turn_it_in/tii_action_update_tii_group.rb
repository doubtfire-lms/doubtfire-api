# freeze_string_literal: true

# Track updating of a group (assignment / task definition) in TurnItIn
class TiiActionUpdateTiiGroup < TiiAction
  def run
    if entity.tii_group_id.present?
      save_and_log_custom_error "Group id exists for task definition #{entity.id}"
      return
    end

    # Generate id but do not save until put is complete
    entity.tii_group_id = SecureRandom.uuid

    data = TCAClient::AggregateGroup.new(
      id: entity.tii_group_id,
      name: entity.detailed_name,
      type: 'ASSIGNMENT',
      group_context: TurnItIn.create_or_get_group_context(entity.unit),
      due_date: entity.due_date,
      report_generation: 'IMMEDIATELY_AND_DUE_DATE'
    )

    exec_tca_call "create or update group #{entity.tii_group_id} for task definition #{entity.id}", [] do
      TCAClient::GroupsApi.new.groups_group_id_put(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        entity.tii_group_id,
        data
      )

      # Save the task definition and complete if save succeeds
      self.complete = entity.save
      # Save action
      save
    end
  rescue TCAClient::ApiError => e
    handle_error e, [
      { code: 404, message: 'Assessment not found in turn it in' }
    ]
    nil
  end
end
