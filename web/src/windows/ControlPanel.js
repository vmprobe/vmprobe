import React from 'react';
import PureComponent from 'react-pure-render/component';

import {Table, Column, Cell} from 'fixed-data-table';



export class ControlPanel extends PureComponent {
  static defaultProps = {
    windowTitle: <span>vm<span style={{color:'#d40000'}}>probe</span></span>,
    defaultWidth: 150,
    defaultHeight: 600,
  }

  render() {
    return (
      <div className="btn-group-vertical" role="toolbar">
        <button type="button" roll="toolbar" className="btn btn-default" onClick={() => this.createWindow("ServerList")}>Server List</button>
        <button type="button" roll="toolbar" className="btn btn-default" onClick={() => this.createWindow("MemInfo")}>Memory Info</button>
        <button type="button" roll="toolbar" className="btn btn-default" onClick={() => this.createWindow("FsCache")}>Filesystem Cache</button>
      </div>
    );
  }

  createWindow(type) {
    this.props.vmprobe_console.sendMsg({
      new: type,
    });
  }
}
