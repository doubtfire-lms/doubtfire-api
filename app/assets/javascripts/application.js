// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require d3.v2
//= require nv.d3
//= require moment
//= require bootstrap-datepicker

// Makes date inputs look sick
$(document).on("focus", "[data-behaviour~='datepicker']", function(e){
    $(this).datepicker({"format": "yyyy-mm-dd", "weekStart": 1, "autoclose": true});
});

function colourForProjectProgress(progress) 
{
  var colour = null;

  switch (progress)
  {
    case "ahead":
      colour = "#48842c"; // Twitter Bootstrap @green
      break;
    case "on_track":
      colour = "#049cdb"; // Twitter Bootstrap @blue
      break;
    case "behind":
      colour = "#f89406"; // Twitter Bootstrap @orange
      break;
    case "danger":
      colour = "#9d261d"; // Twitter Bootstrap @red
      break;
    case "doomed":
      colour = "#000000";
      break;
  }

  return colour;
}