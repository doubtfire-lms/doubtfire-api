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

      projectProgressChart.tooltipContent(function(key, x, y, e, graph){
        return "<h3>" + key + "</h3>"
        + "<p>" + y + " at Week " + x + "</p>";
      });

      d3.select($(burndownChartContainer).children("svg")[0])
          .datum(projectChartData)
        .transition().duration(500)
          .call(projectProgressChart);

      nv.utils.windowResize(projectProgressChart.update);

      return projectProgressChart;
    });
  });
}

function sortTasksByDate(taskA, taskB) {

  var taskADate = moment(taskA.task_template.target_date);
  var taskBDate = moment(taskB.task_template.target_date);

  if (taskADate > taskBDate)
    return 1;
  if (taskADate < taskBDate)
    return -1;

  return 0;
}

function dataForProjectJSON(projectJSON) {
  // Get the project's template
  var templateProject = projectJSON.project_template;
  
  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate = moment(templateProject.start_date);
  var projectCompletionDate = moment(new Date(templateProject.end_date));

  var projectTasks = projectJSON.tasks;
  projectTasks.sort(sortTasksByDate);
  
  var taskCount = projectTasks.length

  // Determine the starting weight for the project based
  // on the number of tasks in the project and the task
  // weight constant
  var weightCountdown = projectJSON.total_task_weight;
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
    if (task.task_template.required === false) {
      return true;
    }

    // Determine the remaining weight value (i.e. y value for the chart)
    weightCountdown = weightCountdown - task.weight;

    // Determine the week at which the task is to be completed at by comparing
    // the 'due date' to the current 
    var taskDueWeek         = moment(task.task_template.target_date).diff(projectStartDate, 'weeks');

    if (task.task_status_id == 3) { // 3 = Complete; TODO: Fix

      remainingWeight = remainingWeight - task.weight;
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

  var recommendedSeries = {
    values: recommendedTaskCompletion,
    key: "Recommended",
    color: "#999999"
  };

  var completedSeries = {
    values: actualTaskCompletion,
    key: "Completed",
    color: colourForProjectProgress(projectJSON.progress)
  }

  var seriesToPlot = [recommendedSeries];

  if (moment(new Date()) >= projectStartDate && projectJSON.completed_tasks_weight > 0) {
    seriesToPlot.push(completedSeries);
  }

  return seriesToPlot;
}

function colourForProjectProgress(progress)  {
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
    case "not_started":
      colour = "#888888";
      break;
  }

  return colour;
}