import React from 'react';
import PureComponent from 'react-pure-render/component';
import {Table, Column, Cell} from 'fixed-data-table';
import Time from 'react-time';
import Tooltip from '../Tooltip';
import * as util from '../util';
import update from '../update';
import CacheSummaryDisplay from '../CacheSummaryDisplay';
import Hostname from '../Hostname';


// https://github.com/facebook/fixed-data-table/blob/master/examples/SortExample.js


export class FsCache extends PureComponent {
  static defaultProps = {
    windowTitle: "Filesystem Cache",
    defaultWidth: 800,
    defaultHeight: 400,
  };

  render() {
    return (
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <Display {...this.props} />
        <Adder {...this.props} />
      </div>
    )
  }
}



function shallowCopyObject(x) {
  return Object.assign(new x.constructor(), x);
}

class Adder extends PureComponent {
  render() {
    let lock_display;

    if (this.props['locks']) {
      let locks = [];

      for (let lock_id of Object.keys(this.props.locks)) {
        let lock = shallowCopyObject(this.props.locks[lock_id]);
        lock['lock_id'] = lock_id;
        locks.push(lock);
      }

      locks.sort((a,b) => b.time - a.time);

      lock_display = locks.map((l) => (
        <span key={l.lock_id} style={{ marginRight: 10 }}>
          <Tooltip
            parent={
              <span className="glyphicon glyphicon glyphicon-lock" ariaHidden="true" />
            }
            tip={
              <div>
                {util.prettyPrintPages(l.num_pages)} of {l.path} locked <Time value={new Date(l.time * 1000)} relative />
              </div>
            }
          />
          <Tooltip tip="Unlock" parent={
            <span style={{ cursor: 'pointer', verticalAlign: 'super', fontSize: '60%', }}
                  className="glyphicon glyphicon glyphicon-remove" ariaHidden="true"
                  onClick={() => this.unlock(l.lock_id)} />
          }/>
        </span>
      ));
    }

    return (
      <div style={{height: 25, display: 'flex', justifyContent: 'space-between'}}>
        <form className="pathAdderForm" onSubmit={this.addPath.bind(this)}>
          <input style={{ marginLeft: 5 }} type="text" placeholder="add path" ref="path" />
        </form>
        <div>
          <span style={{ fontSize: '150%', marginRight: 30 }}>
            {lock_display}
          </span>
          <span style={{ fontSize: '200%' }}>
            <Tooltip tip="Zoom in on page cache display (more details visible, more network traffic required)" parent={
              <span style={{ cursor: 'pointer' }} onClick={this.zoomIn.bind(this)}className="glyphicon glyphicon-zoom-in" ariaHidden="true" />
            }/>
            <Tooltip tip="Zoom out on page cache display (fewer details visible, less network traffic required)" parent={
              <span style={{ cursor: 'pointer' }} onClick={this.zoomOut.bind(this)} className="glyphicon glyphicon-zoom-out" ariaHidden="true" />
            }/>
         </span>
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

  unlock(lock_id) {
    this.props.vmprobe_console.sendMsg({
      resource: this.props.resource_id,
      cmd: 'unlock',
      args: {
        lock_id: lock_id,
      }
    });
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
          <Tooltip tip="Lock selection: Locks pages into memory" parent={
            <span onClick={() => this.lockSelection(paths)} style={{ cursor: 'pointer' }} className="glyphicon glyphicon glyphicon-lock" ariaHidden="true" />
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
              <Hostname hostname={paths[rowIndex][0]} />
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
                <CacheSummaryDisplay
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
              <Tooltip tip="Take a snapshot of this path's cache profile" parent={
                <span onClick={() => this.takeSnapshot.bind(this)(paths[rowIndex])} style={{ cursor: 'pointer' }} className="glyphicon glyphicon-camera" ariaHidden="true" />
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

  takeSnapshot(row) {
    this.props.vmprobe_console.sendMsg({
      resource: this.props.resource_id,
      cmd: 'take_snapshot',
      args: {
        host: row[0],
        path: row[1],
      }
    });
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

  lockSelection(paths) {
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
          cmd: 'lock_sel',
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
