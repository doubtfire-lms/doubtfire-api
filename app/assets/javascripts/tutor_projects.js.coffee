$ ->
  $("#team-list-options button").click (e) ->
    teamToToggle = $(this).attr("id").split("-")[1];
    $("#team-#{teamToToggle}-students").toggle('fast')
    event.preventDefault()

  $(".task-indicator-button").click (e) ->
    buttonClicked       = $(this)
    buttonIdTokens      = buttonClicked.attr("class").split(" ")[2].split("-")

    indicate = buttonIdTokens[buttonIdTokens.length - 1]
    buttonClicked.attr "data-active-indicator", indicate

    $(".task-progress-item").attr "class", ->
      progressItem  = $(this)
      taskIDClass   = progressItem.attr("class").split(" ")[1]
      "task-progress-item #{taskIDClass} #{progressItem.attr("data-#{indicate}-class")}"