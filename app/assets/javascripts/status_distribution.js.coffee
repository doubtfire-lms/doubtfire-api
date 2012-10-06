jQuery ->
  $(".status-distribution-chart").each (i, chartContainer) ->
    constructStatusDistributionChart chartContainer

constructStatusDistributionChart = (chartContainer) ->
  projectURL = $(chartContainer).attr("data-url")

  d3.json projectURL, (project) ->
    return if project.status_distribution.total is 0

    distributionData = projectDistributionData(project)

    nv.addGraph ->
      colours = (progressColour(progress) for progress in [
        "ahead"      
        "on_track"   
        "behind"     
        "danger"     
        "doomed"     
        "not_started"
      ])

      chart = nv.models.pieChart()
              .x((d) -> d.label)
              .y((d) -> d.value)
              .color(colours)
              .showLabels(false)
              .showLegend(false)

      d3.select($(chartContainer).children("svg")[0])
        .datum(distributionData)
        .transition().duration(1200)
        .call(chart)

      chart.tooltipContent (progress, y, e, graph) ->
        "<h3>Status Distribution</h3>
        <p>#{parseFloat(y).toFixed()} project(s) '#{progress}'</p>"

progressColour = (progress) ->
  switch progress
    when "ahead"        then "#48842c" # Twitter Bootstrap @green
    when "on_track"     then "#049cdb" # Twitter Bootstrap @blue
    when "behind"       then "#f89406" # Twitter Bootstrap @orange
    when "danger"       then "#9d261d" # Twitter Bootstrap @red
    when "doomed"       then "#000000" # Black
    when "not_started"  then "#888888" # Grey

projectDistributionData = (project) ->
  [{
    key: "Status",
    values: [
      { label: "Going Well",          value: project.status_distribution.ahead        }
      { label: "Progressing",         value: project.status_distribution.on_track     }
      { label: "Need to Catch Up",    value: project.status_distribution.behind       }
      { label: "Seek Help",           value: project.status_distribution.danger       }
      { label: "Running Out of Time", value: project.status_distribution.doomed       }
      { label: "Not Started",         value: project.status_distribution.not_started  }
    ]
  }]