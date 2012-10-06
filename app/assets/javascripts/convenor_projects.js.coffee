$ ->
	$("#projects th a").live "click", ->
		$.getScript this.href
		false