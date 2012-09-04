$(document).ready(function() {
  $.each($(".task-distribution-chart"), function(i, taskDistributionContainer) {
    constructTaskDistributionChart(taskDistributionContainer);
  });
});

function constructTaskDistributionChart(taskDistributionContainer) {
	var projectTemplateJSONURL = $(taskDistributionContainer).attr("data-url");

	d3.json(projectTemplateJSONURL, function(projectTemplateJSON) {

		var requiredTasks = getRequiredTasks(projectTemplateJSON);
		var taskDistributionData = dataForTasks(requiredTasks);

		nv.addGraph(function() {
			var chart = nv.models.multiBarChart();

			chart.xAxis.tickFormat(function(d, i){
				return d;
			});

			chart.yAxis
			 .tickFormat(d3.format(',f'));

			chart.stacked(true);

			chart.tooltipContent(function(key, x, y, e, graph){
				return "<h3>" + requiredTasks[x - 1].name + "</h3>"
				+ "<p>" + y + " '" + key + "'</p>";
			});

			d3.select($(taskDistributionContainer).children("svg")[0])
			 .datum(taskDistributionData)
			.transition().duration(500).call(chart);

			nv.utils.windowResize(chart.update);

			return chart;
		});
	});
}

function getRequiredTasks(projectTemplateJSON) {
	var requiredTasks = [];
	$.each(projectTemplateJSON.task_templates, function(i, task){
		if (task.required) {
			requiredTasks.push(task);
		}
	});

	return requiredTasks;
}

function dataForTasks(tasks) {
	var taskDistributionData = [
		{ key: "Not Submitted", 	values: [], color: "#999999"},
		{ key: "Need Help", 		values: [], color: "#F6A895"},
		{ key: "Working On It", 	values: [],	color: "#FCEC21"},
		{ key: "Needs Fixing", 		values: [], color: "#FBB450"},
		{ key: "Complete", 			values: [], color: "#62C462"}
	];

	var index = 0;
	$.each(tasks, function(i, task){
		index += 1;

		var taskStatusDistribution = task.status_distribution;
		taskDistributionData[0].values.push({ x: index, y: taskStatusDistribution.not_submitted });
		taskDistributionData[1].values.push({ x: index, y: taskStatusDistribution.need_help });
		taskDistributionData[2].values.push({ x: index, y: taskStatusDistribution.working_on_it });
		taskDistributionData[3].values.push({ x: index, y: taskStatusDistribution.needs_fixing });
		taskDistributionData[4].values.push({ x: index, y: taskStatusDistribution.complete });
	});

	return taskDistributionData;
}