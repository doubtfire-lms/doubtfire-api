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
  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate  = moment(project.project_template.start_date);
  var projectEndDate    = project.project_template.end_date
  // Determine the number of weeks after the project starts that it ends
  var projectEndWeek    = moment(projectEndDate).diff(projectStartDate, 'weeks');

  var projectTasks = project.tasks.sort(sortTasksByTargetDate);

  var projectWeight           = project.total_task_weight
  var remainingWeight         = projectWeight;
  var weekTaskWeightCompleted = {};

  for (var i = 0; i <= projectEndWeek; i++) {
    weekTaskWeightCompleted[i] = 0;
  }

  $.each(projectTasks, function(i, task){

    // Skip the task if it's optional
    if (task.task_template.required === false) {  return true; }

    // Determine the week at which the task is to be completed at by comparing
    // the 'due date' to the current date
    var taskDueDate = task.task_template.target_date;
    var taskDueWeek = moment(taskDueDate).diff(projectStartDate, 'weeks');

    weekTaskWeightCompleted[taskDueWeek] += task.weight;
  });

  var taskCompletionVsWeek = [{x: 0, y: projectWeight}];

  for (var week in weekTaskWeightCompleted) {
    remainingWeight -=  weekTaskWeightCompleted[week];
    taskCompletionVsWeek.push({x: week, y: remainingWeight});
  }

  var lastTaskDueDate = projectTasks[projectTasks.length -1].task_template.target_date;
  var lastTaskDueWeek = moment(lastTaskDueDate).diff(projectStartDate, 'weeks');

  for (var week = lastTaskDueWeek; week <= projectEndWeek; week++) {
    taskCompletionVsWeek.push({x: week, y: 0});
  }
  
  return taskCompletionVsWeek;
}

function actualTaskCompletionData(project) {
  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate  = moment(project.project_template.start_date);
  var projectEndDate    = project.project_template.end_date;

  // Determine the current week
  var currentWeek       = moment().diff(projectStartDate, 'weeks');

  // Get the project's start and end date and wrap them as 'moment' objects
  var projectStartDate  = moment(project.project_template.start_date);
  var completedTasks    = getCompletedTasks(project);

  var projectWeight           = project.total_task_weight
  var remainingWeight         = projectWeight;
  var weekTaskWeightCompleted = {};

  for (var i = 0; i <= currentWeek; i++) {
    weekTaskWeightCompleted[i] = 0;
  }

  $.each(completedTasks, function(i, task){

    // Skip the task if it's optional
    if (task.task_template.required === false) {  return true; }

    // Determine the week at which the task is to be completed at by comparing
    // the 'due date' to the current date
    var taskCompletionDate = moment(task.completion_date);
    var taskCompletionWeek = moment(taskCompletionDate).diff(projectStartDate, 'weeks');

    weekTaskWeightCompleted[taskCompletionWeek] += task.weight;
  });

  var taskCompletionVsWeek = [{x: 0, y: projectWeight}];

   for (var week in weekTaskWeightCompleted) {
    remainingWeight -=  weekTaskWeightCompleted[week];
    taskCompletionVsWeek.push({x: week, y: remainingWeight});
  }

  return taskCompletionVsWeek;
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