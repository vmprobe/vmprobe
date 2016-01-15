import React from 'react';
import PureComponent from 'react-pure-render/component';
import {Table, Column, Cell} from 'fixed-data-table';
import Tooltip from '../Tooltip';
import * as util from '../util';
import update from '../update';


// https://github.com/facebook/fixed-data-table/blob/master/examples/SortExample.js


export class FsCache extends PureComponent {
  static defaultProps = {
    windowTitle: "Filesystem Cache",
    defaultWidth: 800,
    defaultHeight: 400,
  }

  render() {
    return (
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <Display {...this.props} />
        <Adder {...this.props} />
      </div>
    )
  }
}




class Adder extends PureComponent {
  render() {
    return (
      <div style={{height: 25, display: 'flex', justifyContent: 'space-between'}}>
        <form className="pathAdderForm" onSubmit={this.addPath.bind(this)}>
          <input style={{ marginLeft: 5 }} type="text" placeholder="add path" ref="path" />
        </form>
        <div style={{ fontSize: '200%' }}>
          <Tooltip tip="Zoom in on page cache display (more details visible, more network traffic required)" parent={
              <span style={{ cursor: 'pointer' }} onClick={this.zoomIn.bind(this)}className="glyphicon glyphicon-zoom-in" ariaHidden="true" />
          }/>
          <Tooltip tip="Zoom out on page cache display (fewer details visible, less network traffic required)" parent={
            <span style={{ cursor: 'pointer' }} onClick={this.zoomOut.bind(this)} className="glyphicon glyphicon-zoom-out" ariaHidden="true" />
          }/>
        </div>
      </div>
    );
  }

  addPath(e) {
    e.preventDefault();

    let path = this.refs.path.value.trim();

    if (path === '') return;

    this.refs.path.value = '';

    this.props.vmprobe_console.updateParams(
      this.props.resource_id,
      { paths: { $push: [path] } },
    );
  }

  zoomIn() {
    this.props.vmprobe_console.updateParams(
      this.props.resource_id,
      { buckets: { $set: (this.props.params.buckets * 2) } },
    );
  }

  zoomOut() {
    this.props.vmprobe_console.updateParams(
      this.props.resource_id,
      { buckets: { $set: Math.max(1, Math.floor(this.props.params.buckets / 2)) } },
    );
  }
}



class Display extends PureComponent {
  constructor(props) {
    super(props);

    this.state = {
      selections: {},
    };
  }

  render() {
    let paths = [];

    for (let r of this.props.remotes) {
      for (let path of this.props.params.paths) {
        paths.push([r.host, path, (r['fs_cache'] ? r['fs_cache'][path] : undefined)]);
      }
    }

    let selection_details = {
      num_pages: 0,
      num_resident: 0,
      num_files: 0,
    };

    let pages_selected_by_row = [];

    for (let row of paths) {
      let selection = this.selectionToIndices(row);

      let pages_selected = 0;

      if (selection) {
        for (let i = selection[0]; i <= selection[1]; i++) {
          let summary = row[2][i];

          selection_details.num_pages += summary.num_pages;
          selection_details.num_resident += summary.num_resident;
          selection_details.num_files += summary.num_files; // FIXME: how to show partial files?

          pages_selected += summary.num_pages;
        }
      }

      pages_selected_by_row.push(pages_selected);
    }

    let selection_summary;

    if (selection_details.num_pages != 0) {
      selection_summary = (
        <div>
          {util.prettyPrintPages(selection_details.num_resident)} / {util.prettyPrintPages(selection_details.num_pages)} selected
          &nbsp;
          &nbsp;
          &nbsp;
          <Tooltip tip="Touch selection: Bring pages from disk into memory." parent={
            <span onClick={() => this.touchSelection(paths)} style={{ cursor: 'pointer' }} className="glyphicon glyphicon glyphicon-open" ariaHidden="true" />
          }/>
          &nbsp;
          <Tooltip tip="Evict selection: Remove pages from memory. They will need to be fetched from disk on next access." parent={
            <span onClick={() => this.evictSelection(paths)} style={{ cursor: 'pointer' }} className="glyphicon glyphicon glyphicon-save" ariaHidden="true" />
          }/>
          &nbsp;
          <Tooltip tip="Lock selection: Locks pages into memory *NOT IMPLEMENTED YET*" parent={
            <span style={{ cursor: 'pointer' }} className="glyphicon glyphicon glyphicon-lock" ariaHidden="true" />
          }/>
        </div>
      );
    }

    return (
     <div>
      <Table
        rowsCount={paths.length}
        rowHeight={50}
        headerHeight={50}
        width={this.props.windowWidth - 1}
        height={this.props.windowHeight - 50}
      >
        <Column
          header={<Cell>Remote</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              {paths[rowIndex][0]}
            </Cell>
          )}
          width={0}
          flexGrow={1}
        />
        <Column
          header={<Cell>Path</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              {paths[rowIndex][1]}
            </Cell>
          )}
          width={0}  
          flexGrow={1}
        />
        <Column
          header={<Cell>Residency</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>  
              {
                <SummaryDisplay
                  summary={paths[rowIndex][2]}
                  width={(this.props.windowWidth / 2) - 20}
                  selection={this.selectionToIndices(paths[rowIndex])}
                  setSelection={(sel) => this.setSelection(paths[rowIndex], sel)}
                />
              }
            </Cell>
          )}
          width={0}
          flexGrow={3}
        />
        <Column
          header={<Cell>Actions</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              <Tooltip
                parent={
                  <span onClick={() => this.toggleSelect.bind(this)(paths[rowIndex])} style={{ cursor: 'pointer' }} className={pages_selected_by_row[rowIndex] ? "glyphicon glyphicon glyphicon-check" : "glyphicon glyphicon glyphicon-unchecked"} ariaHidden="true" />
                  }
                tip={selection_details.num_pages ? <span>Unselect all pages</span> : <span>Select all pages</span>}
              />
              &nbsp;&nbsp;
              <Tooltip tip="Take snapshot of this path: *NOT IMPLEMENTED YET*" parent={
                <span style={{ cursor: 'pointer' }} className="glyphicon glyphicon-camera" ariaHidden="true" />
              }/>
              &nbsp;&nbsp;
              <Tooltip tip="Remove this path from this window" parent={
                <span onClick={() => this.removePath.bind(this)(paths[rowIndex][1])} style={{ cursor: 'pointer' }} className="glyphicon glyphicon-remove" ariaHidden="true" />
              }/>
            </Cell>
          )}
          width={0}
          flexGrow={1}
        />
      </Table>
      <div style={{ height: 20 }}>
        {selection_summary}
       </div>
     </div>
    );
  }

  removePath(path) {
    this.props.vmprobe_console.updateParams(
      this.props.resource_id,
      { paths: { $splice: [[this.props.params.paths.indexOf(path), 1]] } },
    );
  }

  toggleSelect(row) {
    if (!row[2]) return;
    this.setSelection(row, this.getSelection(row) ? null : [0,1]);
  }

  getSelection(row) {
    if (!this.state.selections[row[0]]) return null;
    return this.state.selections[row[0]][row[1]];
  }

  setSelection(row, new_sel) {
    this.setState({
      selections: update(this.state.selections, {
        [row[0]]: {
          [row[1]]: {
            '$set': new_sel,
          }
        }
      })
    });
  }

  selectionToIndices(row) {
    let selection = this.getSelection(row);
    if (!selection) return null;

    let summary = row[2];

    let sel_start = Math.floor(selection[0] * summary.length);
    let sel_end = Math.floor(selection[1] * summary.length) - 1;

    return [sel_start, sel_end];
  }

  touchSelection(paths) {
    let msgs = [];

    for (let row of paths) {
      let selection = this.selectionToIndices(row);

      if (selection) {
        let start_pages = 0, num_pages = 0;

        for (let i = 0; i <= selection[1]; i++) {
          let summary = row[2][i];

          if (i < selection[0]) start_pages += summary.num_pages;
          else num_pages += summary.num_pages;
        }

        msgs.push({
          resource: this.props.resource_id,
          cmd: 'touch_sel',
          args: {
            host: row[0],
            path: row[1],
            num_pages: num_pages,
            start_pages: start_pages,
          },
        });
      }
    }

    if (msgs.length) this.props.vmprobe_console.sendMsgs(msgs);
  }

  evictSelection(paths) {
    let msgs = [];

    for (let row of paths) {
      let selection = this.selectionToIndices(row);

      if (selection) {
        let start_pages = 0, num_pages = 0;

        for (let i = 0; i <= selection[1]; i++) {
          let summary = row[2][i];

          if (i < selection[0]) start_pages += summary.num_pages;
          else num_pages += summary.num_pages;
        }

        msgs.push({
          resource: this.props.resource_id,
          cmd: 'evict_sel',
          args: {
            host: row[0],
            path: row[1],
            num_pages: num_pages,
            start_pages: start_pages,
          },
        });
      }
    }

    if (msgs.length) this.props.vmprobe_console.sendMsgs(msgs);
  }
}



class SummaryDisplay extends PureComponent {
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
    if (this.state.clicked !== null) {
      this.props.setSelection([this.state.clicked, this.mouseEventToIndexRatio(event)].sort());
    }
  }
}
