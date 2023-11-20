# freeze_string_literal: true

# Module to provide Turnitin integration functionality for Unit
module UnitTiiModule
  def tii_actions
    TiiAction.where(entity: task_definitions)
             .or(TiiAction.where(entity: tii_submissions))
             .or(TiiAction.where(entity: tii_group_attachments))
  end
end
