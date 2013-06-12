$ ->
  $(".task-distribution-chart").each (i, chartContainer) ->
    constructTaskDistributionChart chartContainer

constructTaskDistributionChart = (chartContainer) ->
  projectURL = $(chartContainer).attr "data-url"
  
  d3.json projectURL, (project) ->
    console.log(project)
    requiredTasks     = project.task_templates.filter (task) -> task.required
    requiredTasksMap  = {}
    requiredTasks.forEach (task, i) ->
      taskAbbreviation = task.abbreviation || (i + 1).toString()
      requiredTasksMap[taskAbbreviation] = task

    distributionData  = taskDistributionData(requiredTasks)
    
    nv.addGraph () ->
      chart = nv.models.multiBarChart()
      chart.xAxis.
        tickFormat (d, i) -> requiredTasks[d].abbreviation || (i + 1).toString()
      chart.yAxis.tickFormat(d3.format(',f'))
      chart.stacked true

      chart.tooltipContent (key, x, y, e, graph) ->
        "<h3>#{requiredTasksMap[x].name}</h3>
        <p>#{y} '#{key}'</p>"

      ###
      If under a tab, make sure tab changes re-render chart
      ###
      tab = $(chartContainer).parents ".tab-pane"
      if tab.length 
        tab.each (i,e) ->
          t = $("a[href='##{$(e).attr("id")}'][data-toggle]")
          t.on "shown", -> chart.update()

      d3.select($(chartContainer).children("svg")[0])
        .datum(distributionData)
        .transition().duration(200).call(chart)

      nv.utils.windowResize chart.update

      chart

taskDistributionData = (tasks) ->
  distributionData = [
    { key: "Not Submitted",     values: [], color: "#999999" }
    { key: "Need Help",         values: [], color: "#F6A895" }
    { key: "Working On It",     values: [], color: "#FCEC21" }
    { key: "Fix and Resubmit",  values: [], color: "#FBB450" }
    { key: "Fix and Include",   values: [], color: "#FFD119" }
    { key: "Redo",              values: [], color: "#B06C4E" }
    { key: "Awaiting Signoff",  values: [], color: "#0074CC" }
    { key: "Complete",          values: [], color: "#62C462" }
  ] 

  taskStatuses = [
    "not_submitted"
    "need_help"
    "working_on_it"
    "fix_and_resubmit"
    "fix_and_include"
    "redo"
    "awaiting_signoff"
    "complete"
  ]

  tasks.forEach (task, i) ->
    taskStatuses.forEach (taskStatus, j) ->
      distributionData[j].values.push({ x: i, y: task.status_distribution[taskStatus]})

  distributionData