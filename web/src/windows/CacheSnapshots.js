import React from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from '../Tooltip';
import {Table, Column, Cell} from 'fixed-data-table';

import * as util from '../util';
import CacheSummaryDisplay from '../CacheSummaryDisplay';



export class CacheSnapshots extends PureComponent {
  static defaultProps = {
    windowTitle: "Cache Snapshots",
    defaultWidth: 800,
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
                {files[rowIndex]['filename']}
              </Cell>
            )}
            width={0}
            flexGrow={1}
          />
          <Column
            header={<Cell>Time</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                {"" + new Date(files[rowIndex]['mtime'] * 1000)}
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
                  width={(this.props.windowWidth / 3) - 30}
                />
              </Cell>
            )}
            width={0}
            flexGrow={1}
          />
        </Table>
      </div>
    )
  }
}
