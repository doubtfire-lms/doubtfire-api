$(document).ready(function(){
	$(".task-progress-item").popover({
		trigger: 'manual',
        placement: 'top',
        html: true,
        template: '<div class="popover" onmouseover="$(this).mouseleave(function() {$(this).hide(); });"><div class="arrow"></div><div class="popover-inner"><h3 class="popover-title"></h3><div class="popover-content"><p></p></div></div></div>'
    })
    .click(function(e) {
    	e.preventDefault();
        $(".popover").hide();
        $(this).popover('show');
    });
});