class ResourcesController < ApplicationController
  def download_task_import_template
    send_file "public/resources/task-import-template.csv", :type => "application/csv"
  end
end
