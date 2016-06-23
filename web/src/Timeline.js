import React from 'react';

import d3 from 'd3';

require("../css/timeline.css");


var margin = {top: 20, right: 20, bottom: 30, left: 40},
    width = 860 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;


export default class Timeline extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div className="timeline" ref="chart" />
    )
  }

  shouldComponentUpdate() {
    return false;
  }



  componentDidMount() {
    this.svg = d3.select(this.refs.chart).append("svg");

    this.svg
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    let maxDt = new Date();
    let minDt = new Date(maxDt - 86400*1000);

    this.x = d3.time.scale()
      .domain([minDt, maxDt])
      .range([0, width]);

    this.xAxis = d3.svg.axis()
      .scale(this.x)
      .orient('bottom')
      .tickSize(-height);

    this.svg.append('g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + height + ')')
      .call(this.xAxis);

    this.zoom = d3.behavior.zoom()
        .x(this.x)
        .on('zoom', this.computeZoom.bind(this));

    d3.select("svg").call(this.zoom);

    this.computeZoom();
  }


  addEvents(events) {
    this.svg.selectAll('.dot')
      .data(events, (e) => e.event_id)
      .enter()
      .append('circle')
        .attr('class', 'dot')
        .attr('cx', d => this.x(new Date(d.event_id / 1000)))
        .attr('cy', 50)
        .attr('r', 5);

    this.x.domain(events.map(function(d) { return d.event_id; }));
  }


  computeZoom() {
    this.svg.select('.x.axis').call(this.xAxis);
    this.svg.selectAll('circle.dot').attr('cx', d => this.x(new Date(d.event_id / 1000)));
  }
}
