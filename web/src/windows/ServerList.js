import React from 'react';
import PureComponent from 'react-pure-render/component';
import {Table, Column, Cell} from 'fixed-data-table';
import Tooltip from '../Tooltip';

import Hostname from '../Hostname';




export class ServerList extends PureComponent {
  static defaultProps = {
    windowTitle: "Server List",
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



class CountSummary extends PureComponent {
  render() {
    let num_ok=0, num_err=0, num_other=0;

    for (let remote of this.props.remotes) {
      if (remote.state === 'ok' && remote['version_info']) num_ok++;
      else if (remote.state === 'fail') num_err++;
      else num_other++;
    }

    var count_summary = [];

    if (num_ok) count_summary.push(<span key="num_ok" style={{ color: 'green', marginLeft: 10 }}>
                                     {num_ok}
                                     <span className="glyphicon glyphicon-ok" ariaHidden="true" />
                                   </span>);

    if (num_err) count_summary.push(<span key="num_err" style={{ color: 'red', marginLeft: 10 }}>
                                      {num_err}
                                      <span className="glyphicon glyphicon-fire" ariaHidden="true" />
                                    </span>);

    if (num_other) count_summary.push(<span key="num_other" style={{ marginLeft: 10 }}>
                                        {num_other}
                                        <span className="glyphicon glyphicon-refresh" ariaHidden="true" />
                                      </span>);

    return (
      <span style={{ marginRight: 20 }}>
        {count_summary}
      </span>
    );
  }
}



class Adder extends PureComponent {
  render() {

    return (
      <div style={{height: 25, display: 'flex', justifyContent: 'space-between'}}>
        <form className="serverAdderForm" onSubmit={this.addRemote.bind(this)}>
          <input style={{ marginLeft: 5 }} type="text" placeholder="add server" ref="host" />
        </form>
        <CountSummary {...this.props} />
      </div>
    );
  }

  addRemote(e) {
    e.preventDefault();

    let host = this.refs.host.value.trim();

    if (host === '') return;

    this.refs.host.value = '';

    this.props.vmprobe_console.sendMsg({
      resource: this.props.resource_id,
      cmd: 'add_server',
      args: {
        host: host
      }
    });
  }
}



const ServerStateCell = ({rowIndex, data, ...props}) => {
  let state = data[rowIndex]['state'];

  let style = {};
  let msg = '';

  if (state === 'ok') {
    if (data[rowIndex]['version_info']) {
      msg = <span className="glyphicon glyphicon-ok" ariaHidden="true" />;
      style.color = 'green';
    } else {
      msg = <span className="glyphicon glyphicon-refresh" ariaHidden="true" />;
    }
  } else if (state === 'fail') {
    let errMsg = data[rowIndex]['error_message'];
    msg = (<Tooltip
             parent={<span style={{color: "red"}} className="glyphicon glyphicon-fire" ariaHidden="true" />}
             tip={() => <span style={{color: "red"}}>{errMsg}</span>}
           />);
  } else {
    msg = state;
  }

  let num_connections = data[rowIndex]['num_connections'] || 0;

  return (
    <Cell {...props}>
      <span style={style}>{msg}</span>
      <Tooltip
        tip={`${num_connections} active connections`}
        parent={<span>({num_connections})</span>}
      />
    </Cell>
  );
};



class Display extends PureComponent {
  render() {
    return (
      <Table
        rowsCount={this.props.remotes.length}
        rowHeight={50}
        headerHeight={50}
        width={this.props.windowWidth - 1}
        height={this.props.windowHeight - 25}
      >
        <Column
          header={<Cell>Remote</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              <Hostname hostname={this.props.remotes[rowIndex]['host']} />
            </Cell>
          )}
          width={0}
          flexGrow={2}
        />
        <Column
          header={<Cell>State</Cell>}
          cell={<ServerStateCell data={this.props.remotes} />}
          width={0}
          flexGrow={1}
        />
        <Column
          header={<Cell>Vmprobe</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              {this.props.remotes[rowIndex]['version_info'] && this.props.remotes[rowIndex]['version_info']['vmprobe']}
            </Cell>
          )}
          width={0}
          flexGrow={1}
        />
        <Column
          header={<Cell>OS</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              {this.props.remotes[rowIndex]['version_info'] && this.props.remotes[rowIndex]['version_info']['os_type']}
            </Cell>
          )}
          width={0}
          flexGrow={1}
        />
        <Column
          header={<Cell>Actions</Cell>}
          cell={({rowIndex, ...props}) => (
            <Cell {...props}>
              <Tooltip tip="Disconnect this server." parent={
                <span style={{ display: 'flex', justifyContent: 'space-around' }}>
                  <span onClick={() => this.removeRemote.bind(this)(this.props.remotes[rowIndex]['host'])} style={{ cursor: 'pointer' }} className="glyphicon glyphicon-remove" ariaHidden="true" />
                </span>
              }/>
            </Cell>
          )}
          width={0}
          flexGrow={1}
        />
      </Table>
    );
  }

  removeRemote(host) {
    this.props.vmprobe_console.sendMsg({
      resource: this.props.resource_id,
      cmd: 'remove_server',
      args: {
        host: host
      }
    });
  }
}
