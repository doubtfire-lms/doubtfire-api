$(document).ready(function(){
	$(".toggle-task-description").click(function(event){
		event.preventDefault();
		
		var clickedLink = $(this);
		clickedLink.parent().parent().find(".task-description").first().toggle('fast', function(){
			var icon = clickedLink.children("i");
			if (icon.attr("class") === "icon-chevron-down") {
				icon.attr("class", "icon-chevron-up");
			}
			else {
				icon.attr("class", "icon-chevron-down");	
			}
		});
	});
});