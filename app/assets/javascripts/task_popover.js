$(document).ready(function(){
	$(".task-progress-item").popover({
		trigger: 'manual',
        placement: 'top',
        html: true
    })
    .click(function(e) {
    	$(".popover").hide();
    	e.preventDefault();
    	$(this).popover('toggle');
    });
});