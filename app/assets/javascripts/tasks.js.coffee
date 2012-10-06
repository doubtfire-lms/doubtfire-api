jQuery ->
	$(".toggle-task-description").on 'click', (event) ->
		clickedLink = $(this)
		clickedLink.parent().parent().find(".task-description").first().toggle 'fast', () ->
			icon = clickedLink.children("i")
			direction = if icon.attr "class" is "icon-chevron-down" then "up" else "down"
			icon.attr("class", "icon-chevron-#{direction}")
			
		event.preventDefault()