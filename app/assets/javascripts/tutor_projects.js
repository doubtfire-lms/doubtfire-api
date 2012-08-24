$(document).ready(function(){

	$("#team-list-options button").click(function(event) {
		var teamToToggle = $(this).attr("id").split("-")[1];
		$("#team-" + teamToToggle + "-students").toggle('fast');

		event.preventDefault();
	});

	$(".task-indicator-button").click(function(){

		var buttonClicked 			= $(this);
		var buttonIdTokens 			= buttonClicked.attr("class").split(" ")[2].split("-");

		var indicate = buttonIdTokens[buttonIdTokens.length - 1];
		buttonClicked.attr("data-active-indicator", indicate);

		$(".task-progress-item").attr("class", function(){
			var progressItem = $(this);
			var taskIDClass = progressItem.attr("class").split(" ")[1];
			return "task-progress-item" + " " + taskIDClass + " " + progressItem.attr("data-" + indicate + "-class");
		});
	});
});