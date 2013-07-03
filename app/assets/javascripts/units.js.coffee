$ ->
  $("#projects th a").click ->
    $.getScript this.href
    false