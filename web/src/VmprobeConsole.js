import $ from 'jquery';

import React from 'react';
import PureComponent from 'react-pure-render/component';

import update from './update';

import * as ResourceWindow from './ResourceWindow';

import * as ControlPanel from './windows/ControlPanel';
import * as ServerList from './windows/ServerList';
import * as MemInfo from './windows/MemInfo';
import * as FsCache from './windows/FsCache';


require("../css/bootstrap.min.css");
require("../css/fixed-data-table.css");
require("../css/tooltip.css");
require("../css/window.css");



export default class VmprobeConsole extends PureComponent {
  constructor(props) {
    super(props);

    this.state = {
      session_token: null,
      resources: {},
      nextWindowZIndex: 1,
    };

    $.ajax({
      method: "GET",
      url: "/api/connect",
      dataType: "json",
      success: (data) => {
        this.setState({ session_token: data.token });

        this.getMsgs();
      },
    });
  }

  render() {
    if (this.state.session_token === null) {
      return (
        <div className="vmprobe-console">
          Connecting...
        </div>
      )
    }

    let resources = [];

    for (let resource_id of Object.keys(this.state.resources)) {
      let resource = this.state.resources[resource_id];

      resource = Object.assign(new resource.constructor(), resource); // shallow copy
      resource.resource_id = resource_id;
      resource.vmprobe_console = this;

      resources.push(React.createElement(eval(resource.type + "." + resource.type), resource));
    }

    let resource_windows = resources.map(r => (
      <ResourceWindow.ResourceWindow
        key={r.props.resource_id}
        resource_id={r.props.resource_id}
        getNextWindowZIndex={this.getNextWindowZIndex.bind(this)}
        vmprobe_console={this}
      >
        {r}
      </ResourceWindow.ResourceWindow>
    ));

    return (
      <div className="vmprobe-console">
        <ResourceWindow.ResourceWindow
          key="control-panel"
          getNextWindowZIndex={this.getNextWindowZIndex.bind(this)}
          vmprobe_console={this}
          closeable={false}
        >
          <ControlPanel.ControlPanel vmprobe_console={this} />
        </ResourceWindow.ResourceWindow>

        {resource_windows}
      </div>
    );
  }


  getNextWindowZIndex() {
    let zIndex = this.state.nextWindowZIndex;

    this.setState({ nextWindowZIndex: zIndex+1 });

    return zIndex;
  }


  sendMsg(msg) {
    this.sendMsgs([msg]);
  }

  sendMsgs(msgs) {
    $.ajax({
      method: "POST",
      url: "/api/msg/put",
      dataType: "json",
      data: JSON.stringify({
              token: this.state.session_token,
              msgs: msgs,
            }),
      success: (data) => {},
    });
  }

  updateParams(resource_id, msg) {
    this.sendMsg({
      resource: resource_id,
      cmd: 'params',
      args: msg,
    });
  }

  getMsgs() {
    $.ajax({
      method: "GET",
      url: "/api/msg/get",
      data: { token: this.state.session_token },
      dataType: "json",
      success: (msgs) => {
        for (let msg of msgs) {
          this.handleMsg(msg);
        }

        this.getMsgs();
      },
      error: () => {
        setTimeout(() => this.getMsgs(), 1000);
      },
    });
  }

  handleMsg(msg) {
    this.setState({ resources: update(this.state.resources, msg) });
  }
}
