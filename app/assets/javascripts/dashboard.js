nv.addGraph(function() {  
  var advancedDotNetChart = nv.models.lineChart();

  advancedDotNetChart.xAxis // chart sub-models (ie. xAxis, yAxis, etc) when accessed directly, return themselves, not the partent chart, so need to chain separately
      .axisLabel('Week (w)')
      .tickFormat(d3.format('d'));

  advancedDotNetChart.yAxis
      .axisLabel('Tasks (t)')
      .tickFormat(d3.format(',.2f'));

  d3.select('#chart svg')
      .datum(advancedDotNetBurndown())
    .transition().duration(500)
      .call(advancedDotNetChart);

  //TODO: Figure out a good way to do this automatically
  nv.utils.windowResize(advancedDotNetChart.update);

  return advancedDotNetChart;
});

function advancedDotNetBurndown() {
  var projected = [
    {x: 0, y: 100},
    {x: 1, y: 90},
    {x: 2, y: 80},
    {x: 3, y: 80},
    {x: 4, y: 70},
    {x: 5, y: 60},
    {x: 6, y: 50},
    {x: 7, y: 40},
    {x: 8, y: 30},
    {x: 9, y: 20},
    {x: 10, y: 10},
    {x: 11, y: 0},
  ],
    actual = [
    {x: 0, y: 100},
    {x: 1, y: 100},
    {x: 3, y: 90},
    {x: 3, y: 80},
    {x: 4, y: 70},
    {x: 4, y: 60},
    {x: 4, y: 50},
    {x: 4, y: 40},
    {x: 5, y: 30},
    {x: 6, y: 20},
    {x: 7, y: 10}
  ];

  return [
    {
      values: projected,
      key: "Expected",
      color: "#999999"
    },
    {
      values: actual,
      key: "Actual",
      color: "#F9560F"
    }
  ];
}