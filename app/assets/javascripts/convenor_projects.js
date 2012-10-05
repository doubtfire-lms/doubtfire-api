$(function() {
	$("#projects th a").live("click", function() {
		$.getScript(this.href);
		return false;
	});
});