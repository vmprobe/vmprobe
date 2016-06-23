import React from 'react';

import d3 from 'd3';

require("../css/timeline.css");


let margin = {top: 20, right: 20, bottom: 30, left: 40},
    width = 860 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;

let intial_time_window = 86400;





function shallowCopyObject(x) {
  return Object.assign(new x.constructor(), x);
}




export default class Timeline extends React.Component {
  constructor(props) {
    super(props);

    this.runs = {};
    this.runs_in_progress = {};
    this.runs_overlaps = [[0, {}]];
    this.runs_verticals = {};
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
    let minDt = new Date(maxDt - intial_time_window*1000);

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
    let updated_runs = {};

    for (let e of events) {
        updated_runs[e.run_id] = 1;

        if (e.type === 'new-run') {
            if (this.runs[e.run_id]) throw(`already saw new-run event for ${e.run_id}`);
 
            this.runs[e.run_id] = {
                start: e.info.timestamp,
                argv: e.info.argv,
            };


            this.runs_in_progress[e.run_id] = 1;


            let i, next_vertical;
            for (i = this.runs_overlaps.length-1; this.runs_overlaps[i][0] >= e.info.timestamp; i--) {}
            for (next_vertical = 0; this.runs_overlaps[i][1][next_vertical]; next_vertical++) {}
            for (; i < this.runs_overlaps.length; i++) { this.runs_overlaps[i][1][next_vertical] = 1; }

            this.runs_verticals[e.run_id] = next_vertical;
        } else if (e.type === 'end-run') {
            if (!this.runs[e.run_id]) throw(`haven't seen new-run event for ${e.run_id}`);

            this.runs[e.run_id].end = e.info.timestamp;


            delete this.runs_in_progress[e.run_id];


            this.runs_overlaps.push([ e.info.timestamp, shallowCopyObject(this.runs_overlaps[this.runs_overlaps.length-1][1])]);
            delete this.runs_overlaps[this.runs_overlaps.length-1][1][ this.runs_verticals[e.run_id] ];
        }
    }

    let sel = this.svg.selectAll('.run-bar').data(Object.keys(updated_runs), (e) => e);

    sel.enter()
      .append('rect')
      .attr('height', 20);

    this.updateRunBars(sel);
  }


  computeZoom() {
    //console.log(intial_time_window / this.zoom.scale());

    this.svg.select('.x.axis').call(this.xAxis);
    this.updateRunBars(this.svg.selectAll('rect.run-bar'));
  }


  updateRunBars(sel) {
    let now = new Date();

    sel
      .attr('class', event_id => 'run-bar' + (this.runs[event_id].end ? '' : ' in-progress'))

      .attr('x', event_id => { return this.x(new Date(this.runs[event_id].start / 1000)) })

      .attr('y', event_id => { return 50 + (25 * this.runs_verticals[event_id]) })

      .attr('width', event_id => {
        let e = this.runs[event_id];

        let width = this.x(e.end ? new Date(e.end / 1000) : now) - this.x(new Date(e.start / 1000));

        return Math.max(width, 2);
      })
    ;

    if (Object.keys(this.runs_in_progress).length) {
      if (!this.autoUpdaterInterval) {
        this.autoUpdaterInterval = setInterval(() => this.updateRunBars(this.svg.selectAll('rect.run-bar')), 1000);
      }
    } else {
      clearInterval(this.autoUpdaterInterval);
      delete this['autoUpdaterInterval'];
    }
  }
}
