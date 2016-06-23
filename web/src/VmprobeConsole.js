import React from 'react';
import PureComponent from 'react-pure-render/component';

import update from './update';
import Timeline from './Timeline';

import $ from 'jquery';

require("../css/bootstrap.min.css");



export default class VmprobeConsole extends PureComponent {
  constructor(props) {
    super(props);

    this.state = {
      session_token: null,
      events: [],
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

    return (
      <div>
        <Timeline events={this.state.events} ref="timeline" />
      </div>
    );
  }


  getMsgs() {
    $.ajax({
      method: "GET",
      url: "/api/get_events",
      data: { token: this.state.session_token, from: this.state.latest_event_id },
      dataType: "json",
      success: (msgs) => {
        this.handleMsgs(msgs);
        this.getMsgs();
      },
      error: () => {
        setTimeout(() => this.getMsgs(), 1000);
      },
    });
  }

  handleMsgs(msgs) {
    for (let msg of msgs) {
        this.setState(update(this.state, { latest_event_id: { $set: msg.event_id }, events: { $push: [msg] } }));
    }

    this.refs.timeline.addEvents(msgs);
  }
}
