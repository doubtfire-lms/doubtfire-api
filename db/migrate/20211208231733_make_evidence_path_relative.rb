class MakeEvidencePathRelative < ActiveRecord::Migration
  def up
    root = FileHelper.student_work_dir

    connection.exec_update(<<-EOQ, "SQL", [[nil, root], [nil, "#{root}%"]])
      UPDATE  tasks
      SET     portfolio_evidence = REPLACE(portfolio_evidence, $1, '')
      WHERE   portfolio_evidence like $2
    EOQ
  end

  def down
    root = FileHelper.student_work_dir

    connection.exec_update(<<-EOQ, "SQL", [])
      UPDATE  tasks
      SET     portfolio_evidence = CONCAT('#{root}', portfolio_evidence)
      WHERE   portfolio_evidence not like '/%'
    EOQ
  end
end
