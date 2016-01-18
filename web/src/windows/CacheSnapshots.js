import React from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from '../Tooltip';
import {Table, Column, Cell} from 'fixed-data-table';

import * as util from '../util';



export class CacheSnapshots extends PureComponent {
  static defaultProps = {
    windowTitle: "Cache Snapshots",
  };


  render() {
    if (!this.props.snapshots) {
      return <div>&mdash;</div>;
    }

    return (
      <div>
        <Table
          rowsCount={this.props.snapshots.length}
          rowHeight={50}
          headerHeight={50}
          width={this.props.windowWidth - 1}
          height={this.props.windowHeight - 75}
        >
          <Column
            header={<Cell>Snapshot</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                {this.props.snapshots[rowIndex]['filename']}
              </Cell>
            )}
            width={0}
            flexGrow={1}
          />
          <Column
            header={<Cell>Time</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                {this.props.snapshots[rowIndex]['mtime']}
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



class MemoryUsageBar extends PureComponent {
  render() {
    let mem = this.props.mem_info;

    let segments = [];

    if (!mem) return <div/>;

    let used_pages = mem['MemTotal'] - mem['MemFree'] - mem['Buffers'] - mem['Cached'] - mem['Slab'];

    return (
      <div>
        <MemoryUsageBarSegment
          title="Used"
          desc="Anonymous memory used by applications."
          color={'#21C547'}
          pages={used_pages}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Slab"
          desc="In-kernel data structures which include the dentry and inode caches."
          color={'yellow'}
          pages={mem['Slab']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Buffers"
          desc="Relatively temporary storage for raw disk blocks that shouldn't get tremendously large."
          color={'blue'}
          pages={mem['Buffers']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Page cache"
          desc="In-memory cache for files read from the disk, also know as the pagecache. Note that this doesn't include pages in the swap cache."
          color={'#00FAFF'}
          pages={mem['Cached']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Free"
          desc="Free memory that is available for use by programs, the page-cache, or the kernel."
          color={'black'}
          pages={mem['MemFree']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
      </div>
    );
  }
}




class MemoryUsageBarSegment extends PureComponent {
  render() {
    let box = (
      <span
        style={{
                 width: this.props.width * this.props.pages / this.props.totalPages,
                 height: this.props.height,
                 backgroundColor: this.props.color,
                 display: 'inline-block',
              }}
      />
    );

    let tip = () => (
      <div style={{ width: 300 }}>
        <div><b>{this.props.title}</b></div>
        <div>
          {util.prettyPrintPages(this.props.pages)} / {util.prettyPrintPages(this.props.totalPages)}
          &nbsp;
          ({(100.0 * this.props.pages / this.props.totalPages).toFixed(1)}%)
        </div>
        <div>{this.props.desc}</div>
      </div>
    );

    return (
      <Tooltip
        key="used"
        parent={box}
        tip={tip}
      />
    );
  }
}
