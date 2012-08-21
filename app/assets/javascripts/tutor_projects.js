$(document).ready(function(){

	$("#team-list-options button").click(function(event) {
		var teamToToggle = $(this).attr("id").split("-")[1];
		$("#team-" + teamToToggle + "-students").toggle('fast');

		event.preventDefault();
	});

	$(".task-indicator-button").click(function(){

		var buttonClicked 	= $(this);
		var buttonIdTokens 	= buttonClicked.attr("class").split(" ")[2].split("-");
		var indicate 		= buttonIdTokens[buttonIdTokens.length - 1];

		$(".task-progress-item").attr("class", function(){
			var progressItem = $(this);
			return "task-progress-item" + " " + progressItem.attr("data-" + indicate + "-class");
		});
	});
});