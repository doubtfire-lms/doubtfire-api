$(document).ready(function(){

	$("#team-list-options li button").click(function(event) {
		var shouldInclude = ($(this).parent().attr("data-include") === 'true');
		var teamToToggle = $(this).parent().attr("id").split("-")[1];

		$("#team-" + teamToToggle + "-students").toggle('fast');

		event.preventDefault();
	});
});