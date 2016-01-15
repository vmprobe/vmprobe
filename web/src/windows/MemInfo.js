import React from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from '../Tooltip';
import {Table, Column, Cell} from 'fixed-data-table';

import * as util from '../util';


// Active(file) + Inactive(file) + Shmem = Cached + Buffer
// https://www.reddit.com/r/linux/comments/1hk5ow/free_buffer_swap_dirty_procmeminfo_explained/


export class MemInfo extends PureComponent {
  static defaultProps = {
    windowTitle: "Memory Info",
  }


  render() {
    if (!this.props.remotes || this.props.remotes.length == 0) {
      return <div>No remotes connected</div>;
    }

    let totalMemInfo = {
      MemTotal: 0,
      MemFree: 0,
      Buffers: 0,
      Cached: 0,
      Slab: 0,
    };

    let numRemotes = 0;

    for (let remote of this.props.remotes) {
      if (remote.mem_info) {
        numRemotes++;
        totalMemInfo.MemTotal += remote.mem_info.MemTotal;
        totalMemInfo.MemFree += remote.mem_info.MemFree;
        totalMemInfo.Buffers += remote.mem_info.Buffers;
        totalMemInfo.Cached += remote.mem_info.Cached;
        totalMemInfo.Slab += remote.mem_info.Slab;
      }
    }

    if (numRemotes == 0) {
      return <div>No remotes with memory info available</div>;
    }

    return (
      <div>
        Total:
        <MemoryUsageBar height={50} width={this.props.windowWidth} mem_info={totalMemInfo} {...this.props} />

        <Table
          rowsCount={this.props.remotes.length}
          rowHeight={50}
          headerHeight={50}
          width={this.props.windowWidth - 1}
          height={this.props.windowHeight - 75}
        >
          <Column
            header={<Cell>Remote</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                {this.props.remotes[rowIndex]['host']}
              </Cell>
            )}
            width={0}
            flexGrow={1}
          />
          <Column
            header={<Cell>Memory Info</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                {
                  this.props.remotes[rowIndex].mem_info
                  ? <MemoryUsageBar height={30} width={this.props.windowWidth / 2} mem_info={this.props.remotes[rowIndex].mem_info} {...this.props} />
                  : this.props.remotes[rowIndex]['remote_state'] === 'fail'
                  ? <span style={{ color: 'red' }} className="glyphicon glyphicon-fire" ariaHidden="true" />
                  : <span className="glyphicon glyphicon-refresh" ariaHidden="true" />
                }
              </Cell>
            )}
            width={0}
            flexGrow={3}
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
