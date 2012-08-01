$(document).ready(function() {
  $.each($(".burndownchart"), function(i, burndownChartContainer) {
    constructBurndownChart(burndownChartContainer);
  });
});

function constructBurndownChart(burndownChartContainer) {
  var projectJSONURL = $(burndownChartContainer).attr("data-url");

  d3.json(projectJSONURL, function(projectJSON) {
    var projectChartData = dataForProjectJSON(projectJSON);

    nv.addGraph(function() {  
      var projectProgressChart = nv.models.lineChart();

      projectProgressChart.xAxis // chart sub-models (ie. xAxis, yAxis, etc) when accessed directly, return themselves, not the partent chart, so need to chain separately
          .axisLabel('Week (w)')
          .tickFormat(d3.format('d'));

      projectProgressChart.yAxis
          .axisLabel('Tasks (t)')
          .tickFormat(d3.format(',.2f'));

      d3.select($(burndownChartContainer).children("svg")[0])
          .datum(projectChartData)
        .transition().duration(500)
          .call(projectProgressChart);
      
      nv.utils.windowResize(projectProgressChart.update);

      return projectProgressChart;
    });
  });
}

function dataForProjectJSON(projectJSON) {

  // TODO: Get rid of this constant once the project
  // weight is being properly set
  var TASK_WEIGHT = 2;

  // Get the project's template
  var templateProject = projectJSON.project_template;
  
  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate = moment(templateProject.start_date);
  var projectCompletionDate = moment(new Date(templateProject.end_date));

  var projectTasks = projectJSON.tasks;
  var taskCount = projectTasks.length

  // Determine the starting weight for the project based
  // on the number of tasks in the project and the task
  // weight constant
  var weightCountdown = taskCount * TASK_WEIGHT;
  var remainingWeight = weightCountdown;

  // Set an initial point for the week prior to starting,
  // when no tasks have yet been completed
  var recommendedTaskCompletion = [
    {x: 0, y: weightCountdown}
  ];

  var actualTaskCompletion = [
    {x: 0, y: weightCountdown}
  ];

  $.each(projectTasks, function(i, task){
    // Determine the remaining weight value (i.e. y value for the chart)
    weightCountdown = weightCountdown - TASK_WEIGHT;

    // Determine the week at which the task is to be completed at by comparing
    // the 'due date' to the current 
    var taskDueWeek         = moment(task.task_template.recommended_completion_date).diff(projectStartDate, 'weeks');

    if (task.task_status_id == 3) { // 3 = Complete; TODO: Fix

      remainingWeight = remainingWeight - TASK_WEIGHT;
      var taskCompletionDate = null;

      if (task.completion_date != null) {
        var momentedTaskCompletionDate = moment(task.completion_date);
        taskCompletionDate = momentedTaskCompletionDate.diff(projectStartDate) < 0 ? projectStartDate : momentedTaskCompletionDate;
      } else {
        taskCompletionDate = moment(projectStartDate);
      }

      var taskCompletionWeek  = taskCompletionDate.diff(projectStartDate, 'weeks');
      actualTaskCompletion.push({x: taskCompletionWeek, y: remainingWeight});
    }

    recommendedTaskCompletion.push({x: taskDueWeek, y: weightCountdown});
  });

  recommendedTaskCompletion.push({x: projectCompletionDate.diff(projectStartDate, 'weeks'), y: 0});

  var recommendedSeries = {
    values: recommendedTaskCompletion,
    key: "Recommended",
    color: "#999999"
  };

  var completedSeries = {
    values: actualTaskCompletion,
    key: "Completed",
    color: colourForProjectProgress(projectJSON.relative_progress)
  }

  var seriesToPlot = [recommendedSeries];

  if (moment(new Date()) >= projectStartDate) {
    seriesToPlot.push(completedSeries);
  }

  return seriesToPlot;
}

function colourForProjectProgress(progress) {
  var colour = null;

  switch (progress)
  {
    case "ahead":
      colour = "#48842c"; // Twitter Bootstrap @green
      break;
    case "on_track":
      colour = "#049cdb"; // Twitter Bootstrap @blue
      break;
    case "behind":
      colour = "#f89406"; // Twitter Bootstrap @orange
      break;
    case "danger":
      colour = "#9d261d"; // Twitter Bootstrap @red
      break;
    case "doomed":
      colour = "#000000";
      break;
  }

  return colour;
}