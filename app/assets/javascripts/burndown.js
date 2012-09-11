 $(document).ready(function() {
  $.each($(".burndownchart"), function(i, burndownChartContainer) {
    constructBurndownChart(burndownChartContainer);
  });
});

function constructBurndownChart(burndownChartContainer) {
  var projectJSONURL = $(burndownChartContainer).attr("data-url");

  d3.json(projectJSONURL, function(project) {
    var projectChartData = dataForProject(project);

    nv.addGraph(function() {  
      var projectProgressChart = nv.models.lineChart();

      projectProgressChart.xAxis // chart sub-models (ie. xAxis, yAxis, etc) when accessed directly, return themselves, not the partent chart, so need to chain separately
          .axisLabel('Week (w)')
          .tickFormat(d3.format('d'));

      projectProgressChart.yAxis
          .axisLabel('Task Units Completed (t)')
          .tickFormat(d3.format(',.2f'));

      projectProgressChart.tooltipContent(function(key, x, y, e, graph){
        var displayString = "<h3>" + key + "</h3>";

        if (key === "Target Completion") {
          displayString += "<p>" + y + " by Week " + x + "</p>";
        }
        else {
          displayString += "<p>" + y + " at Week " + x + "</p>";
        }

        return displayString;
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

function sortTasksByTargetDate(taskA, taskB) {

  var taskADate = moment(taskA.task_template.target_date);
  var taskBDate = moment(taskB.task_template.target_date);

  if (taskADate > taskBDate)
    return 1;
  if (taskADate < taskBDate)
    return -1;

  return 0;
}

function sortTasksByCompletionDate(taskA, taskB) {

  var taskADate = moment(taskA.completion_date);
  var taskBDate = moment(taskB.completion_date);

  if (taskADate > taskBDate)
    return 1;
  if (taskADate < taskBDate)
    return -1;

  return 0;
}

function getCompletedTasks(project) {
  var completedTasks = [];

  $.each(project.tasks, function(i, task){
    if (task.task_status_id === 3) {
      completedTasks.push(task);
    }
  });

  return completedTasks.sort(sortTasksByCompletionDate);
}

function targetCompletionData(project) {
  var weightCountdown = project.total_task_weight;

  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate = moment(project.project_template.start_date);

  var projectTasks = project.tasks.sort(sortTasksByTargetDate);

  var data = [{x: 0, y: weightCountdown}];

  $.each(projectTasks, function(i, task){
    if (task.task_template.required === false) {
      return true;
    }

    // Determine the week at which the task is to be completed at by comparing
    // the 'due date' to the current 
    var taskDueWeek         = moment(task.task_template.target_date).diff(projectStartDate, 'weeks');

    // Determine the remaining weight value (i.e. y value for the chart)
    weightCountdown = weightCountdown - task.weight;
    data.push({x: taskDueWeek, y: weightCountdown});
  });
  
  return data;
}

function actualTaskCompletionData(project) {
  var weightCountdown = project.total_task_weight;
  var data = [{x: 0, y: weightCountdown}];

  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate  = moment(project.project_template.start_date);
  var completedTasks    = getCompletedTasks(project);

  var remainingWeight = weightCountdown;

  $.each(completedTasks, function(i, task){
    if (task.task_template.required === false) {
      return true;
    }

    remainingWeight = remainingWeight - task.weight;
    var taskCompletionDate = null;

    if (task.completion_date != null) {
      var momentedTaskCompletionDate = moment(task.completion_date);
      taskCompletionDate = momentedTaskCompletionDate.diff(projectStartDate) < 0 ? projectStartDate : momentedTaskCompletionDate;
    } else {
      taskCompletionDate = moment(projectStartDate);
    }

    var taskCompletionWeek = moment(task.task_template.completion_date).diff(projectStartDate, 'weeks');
    data.push({x: taskCompletionWeek, y: remainingWeight});
  });

  return data;
}

function dataForProject(project) {
  var targetSeries = {
    key: "Target Completion",
    values: targetCompletionData(project),
    color: "#999999"
  };

  var completedSeries = {
    key: "Actual Completion",
    values: actualTaskCompletionData(project),
    color: colourForProjectProgress(project.progress)
  }

  var seriesToPlot = [targetSeries];

  if (moment(new Date()) >= moment(project.project_template.start_date) && project.completed_tasks_weight > 0) {
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