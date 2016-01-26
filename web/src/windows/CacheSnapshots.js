import React from 'react';
import PureComponent from 'react-pure-render/component';

import SnapshotDraggable from '../SnapshotDraggable';
import Time from 'react-time';

import Tooltip from '../Tooltip';
import TooltipSame from '../TooltipSame';
import {Table, Column, Cell} from 'fixed-data-table';

import * as util from '../util';
import CacheSummaryDisplay from '../CacheSummaryDisplay';



export class CacheSnapshots extends PureComponent {
  static defaultProps = {
    windowTitle: (self) => "Cache Snapshots" + (self.props.params.snapshot_dir ? `: ${self.props.params.snapshot_dir}` : ''),
    defaultWidth: 1000,
    defaultHeight: 400,
  };

  render() {
    if (!this.props.snapshots) {
      return <div>&mdash;</div>;
    }

    let files = [];

    for (let filename of Object.keys(this.props.snapshots)) {
      files.push(this.props.snapshots[filename]);
    }

    files.sort((a,b) => b.mtime - a.mtime);

    return (
      <div>
        <Table
          rowsCount={files.length}
          rowHeight={50}
          headerHeight={50}
          width={this.props.windowWidth - 1}
          height={this.props.windowHeight}
        >
          <Column
            header={<Cell>Snapshot</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                <SnapshotDraggable filename={files[rowIndex]['filename']} handleDrop={(hostname) => this.restoreSnapshot(files[rowIndex], hostname)} />&nbsp;
              </Cell>
            )}
            width={0}
            flexGrow={2}
          />
          <Column
            header={<Cell>Host</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                <TooltipSame item={files[rowIndex]['host']} />
              </Cell>
            )}
            width={0}
            flexGrow={2}
          />
          <Column
            header={<Cell>Path</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                <TooltipSame item={files[rowIndex]['path']} />
              </Cell>
            )}
            width={0}
            flexGrow={2}
          />
          <Column
            header={<Cell>Time</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                <Time value={new Date(files[rowIndex]['mtime'] * 1000)} titleFormat="YYYY/MM/DD HH:mm" relative />
              </Cell>
            )}
            width={0}  
            flexGrow={1}
          />
          <Column
            header={<Cell>Display</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                <CacheSummaryDisplay
                  summary={files[rowIndex]['summary']}
                  width={(this.props.windowWidth / 3) - 62}
                />
              </Cell>
            )}
            width={0}
            flexGrow={3}
          />
        </Table>
      </div>
    )
  }

  restoreSnapshot(row, hostname) {
    this.props.vmprobe_console.sendMsg({
      resource: this.props.resource_id,
      cmd: 'restore_snapshot',
      args: {
        hostname: hostname,
        snapshot_path: row['snapshot_path'],
      },
    });
  }
}
