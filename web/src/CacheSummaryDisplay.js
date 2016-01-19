import React from 'react';
import PureComponent from 'react-pure-render/component';
import Tooltip from './Tooltip';
import * as util from './util';
import update from './update';


export default class CacheSummaryDisplay extends PureComponent {
  constructor(props) {
    super(props);

    this.state = {
      clicked: null,
    };
  }

  render() {
    if (!this.props.summary) return <span className="glyphicon glyphicon-refresh" ariaHidden="true" />;

    let item_width = this.props.width / this.props.summary.length;

    let blocks = [];

    for (let index in this.props.summary) {
      let block = this.props.summary[index];

      let selected = this.props.selection && index >= this.props.selection[0] && index <= this.props.selection[1];

      let base = 220;
      let comp = base - Math.floor(base * (block.num_resident / block.num_pages));
      let color = `rgb(${selected ? 10 : comp},${comp},${selected ? 140 : base})`;

      blocks.push(
        <span key={index} style={{ height: 33, width: item_width, backgroundColor: color, display: 'inline-block', }}></span>
      );
    }

    let tipRender = (x, y) => {
      let item_index = Math.min(this.props.summary.length-1, Math.floor(x / item_width));
      let block = this.props.summary[item_index];

      return (
        <div>
          {block.num_files == 0 ? `${block.start_page_offset} pages offset...` : null}
          {block.start_filename}
          {block.num_files > 1 ? `...(${block.num_files-1} others)` : null}
          <br/>
          {util.prettyPrintPages(block.num_resident)} / {util.prettyPrintPages(block.num_pages)}<br/>
        </div>
      );
    };

    return (
      <div onMouseDown={this.handleMouseDown.bind(this)}
           onMouseUp={this.handleMouseUp.bind(this)}
           onMouseOver={this.handleMouseOver.bind(this)}
        >
        <Tooltip
          key="used"
          parent={<div>{blocks}</div>}
          tip={tipRender}
        />
      </div>
    );
  }

  mouseEventToIndexRatio(event) {
    let x_offset = event.pageX - event.target.parentElement.getBoundingClientRect().left;
    let ratio = x_offset / this.props.width;
    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;
    return ratio;
  }

  handleMouseDown(event) {
    this.setState(update(this.state, { clicked: { $set: this.mouseEventToIndexRatio(event) } }));
  }

  handleMouseUp(event) {
    this.setState(update(this.state, { clicked: { $set: null } }));
  }

  handleMouseOver(event) {
    if (this.state.clicked !== null && this.props.setSelection) {
      this.props.setSelection([this.state.clicked, this.mouseEventToIndexRatio(event)].sort());
    }
  }
}
