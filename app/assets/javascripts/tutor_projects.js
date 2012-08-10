$(document).ready(function(){

	$("#team-list-options li a").click(function(event){
		var shouldInclude = ($(this).attr("data-include") === 'true');
		var teamToToggle = $(this).attr("id").split("-")[1];

		$("#team-" + teamToToggle + "-students").toggle();

		event.preventDefault();
	});
});