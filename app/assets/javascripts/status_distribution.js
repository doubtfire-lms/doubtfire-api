$(document).ready(function() {
  $.each($(".status-distribution-chart"), function(i, statusDistributionContainer) {
    constructStatusDistributionChart(statusDistributionContainer);
  });
});

function constructStatusDistributionChart(statusDistributionContainer) 
{
  var projectJSONURL = $(statusDistributionContainer).attr("data-url");

  d3.json(projectJSONURL, function(projectJSON) {
  
  statuses = [ 
  {
    key: "Status",
    values: [
      { 
        "label" : "Ahead" ,
        "value" : projectJSON.status_distribution.ahead
      } , 
      { 
        "label" : "On track" , 
        "value" : projectJSON.status_distribution.on_track
      } , 
      { 
        "label" : "Behind" , 
        "value" : projectJSON.status_distribution.behind
      } , 
      { 
        "label" : "In danger" , 
        "value" : projectJSON.status_distribution.in_danger
      } , 
      { 
        "label" : "Doomed" ,
        "value" : projectJSON.status_distribution.doomed
      }
    ]
  } 
  ];
    nv.addGraph(function() {  

      var width = 150,
          height = 150;

      var chart = nv.models.pieChart()
          .x(function(d) { return d.label })
          .y(function(d) { return d.value })
          .color(d3.scale.category10().range())
          .showLabels(false)
          .showLegend(false)
          .width(width)
          .height(height);

      d3.select($(statusDistributionContainer).children("svg")[0])
          .datum(statuses)
          .transition().duration(1200)
          .attr('width', width)
          .attr('height', height)
          .call(chart);

      return chart;
    });
  });
}