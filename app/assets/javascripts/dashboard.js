$(document).ready(function() {
  var projectJSONURL = projectURL + ".json";

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

      d3.select('#burndownchart svg')
          .datum(projectChartData)
        .transition().duration(500)
          .call(projectProgressChart);

      return projectProgressChart;
    });
  });
});

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
  var remainingWeight = taskCount * TASK_WEIGHT;

  // Set an initial point for the week prior to starting,
  // when no tasks have yet been completed
  var recommendedTaskCompletion = [
    {x: 0, y: remainingWeight}
  ];

  // 
  $.each(projectTasks, function(i, task){
    // Determine the remaining weight value (i.e. y value for the chart)
    remainingWeight = remainingWeight - TASK_WEIGHT;

    // Determine the week at which the task is to be completed at by comparing
    // the 'due date' to the current 
    var week = moment(task.task_template.recommended_completion_date).diff(projectStartDate, 'weeks');
    recommendedTaskCompletion.push({x: week, y: remainingWeight});
  });

  recommendedTaskCompletion.push({x: projectCompletionDate.diff(projectStartDate, 'weeks'), y: 0});

  return [
    {
      values: recommendedTaskCompletion,
      key: "Recommended",
      color: "#999999"
    }
  ];
}