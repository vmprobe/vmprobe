import React from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from '../Tooltip';
import {Table, Column, Cell} from 'fixed-data-table';

import * as util from '../util';
import Hostname from '../Hostname';


// AnonPages + SwapCached + Buffers + Cached + Slab + PageTables + MemFree


export class MemInfo extends PureComponent {
  static defaultProps = {
    windowTitle: "Memory Info",
    defaultWidth: 800,
  };


  constructor(props) {
    super(props);

    this.state = {
      showLRU: false,
    };
  }


  render() {
    if (!this.props.remotes || this.props.remotes.length == 0) {
      return <div>No remotes connected</div>;
    }

    let totalMemInfo = {
      MemTotal: 0,
      AnonPages: 0,
      SwapCached: 0,
      Buffers: 0,
      Cached: 0,
      Slab: 0,
      PageTables: 0,
      MemFree: 0,

      'Active(anon)': 0,
      'Inactive(anon)': 0,
      'Active(file)': 0,
      'Inactive(file)': 0,
    };

    let numRemotes = 0;

    for (let remote of this.props.remotes) {
      if (remote.mem_info) {
        numRemotes++;
        totalMemInfo.MemTotal += remote.mem_info.MemTotal;
        totalMemInfo.AnonPages += remote.mem_info.AnonPages;
        totalMemInfo.SwapCached += remote.mem_info.SwapCached;
        totalMemInfo.Buffers += remote.mem_info.Buffers;
        totalMemInfo.Cached += remote.mem_info.Cached;
        totalMemInfo.Slab += remote.mem_info.Slab;
        totalMemInfo.PageTables += remote.mem_info.PageTables;
        totalMemInfo.MemFree += remote.mem_info.MemFree;

        totalMemInfo['Active(anon)'] += remote.mem_info['Active(anon)'];
        totalMemInfo['Inactive(anon)'] += remote.mem_info['Inactive(anon)'];
        totalMemInfo['Active(file)'] += remote.mem_info['Active(file)'];
        totalMemInfo['Inactive(file)'] += remote.mem_info['Inactive(file)'];
      }
    }

    if (numRemotes == 0) {
      return <div>No remotes with memory info available</div>;
    }

    return (
      <div>
        <MemoryUsageBar height={60} width={this.props.windowWidth - 2} mem_info={totalMemInfo} showLRU={this.state.showLRU} {...this.props} />

        <div>
          <span style={{ cursor: 'pointer' }} onClick={() => this.setState({ showLRU: !this.state.showLRU })}>Show LRU lists <span className={this.state.showLRU ? "glyphicon glyphicon-check" : "glyphicon glyphicon-unchecked"} ariaHidden="true" /></span>
        </div>

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
                <Hostname hostname={this.props.remotes[rowIndex]['host']} />
              </Cell>
            )}
            width={0}
            flexGrow={1}
          />
          <Column
            header={<Cell>Memory</Cell>}
            cell={({rowIndex, ...props}) => (
              <Cell {...props}>
                <span>{this.props.remotes[rowIndex].mem_info && util.prettyPrintPages(this.props.remotes[rowIndex].mem_info['MemTotal'])}</span>
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
                  ? <MemoryUsageBar height={37} width={this.props.windowWidth / 1.7} mem_info={this.props.remotes[rowIndex].mem_info} showLRU={this.state.showLRU} {...this.props} />
                  : this.props.remotes[rowIndex]['remote_state'] === 'fail'
                  ? <span style={{ color: 'red' }} className="glyphicon glyphicon-fire" ariaHidden="true" />
                  : <span className="glyphicon glyphicon-refresh" ariaHidden="true" />
                }
              </Cell>
            )}
            width={0}
            flexGrow={4}
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

    let other_main = mem['MemTotal'] - mem['AnonPages'] - mem['SwapCached'] - mem['Buffers'] - mem['Cached'] - mem['Slab'] - mem['PageTables'] - mem['MemFree'];
    let other_active = mem['MemTotal'] - mem['Active(anon)'] - mem['Inactive(anon)'] - mem['Active(file)'] - mem['Inactive(file)']- mem['MemFree'];

    return (
      <div style={{ height: this.props.height, lineHeight: 0 }}>
       <div style={{ height: this.props.height * (this.props.showLRU ? 0.5 : 1)}}>
        <MemoryUsageBarSegment
          title="Used"
          desc="Anonymous memory (not backed by files) that are in use by applications."
          color={'#21C547'}
          pages={mem['AnonPages']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Swap cache"
          desc="Memory that once was swapped out, is swapped back in but still also is in the swapfile (if memory is needed it doesn't need to be swapped out AGAIN because it is already in the swapfile. This saves I/O)"
          color={'#24C547'}
          pages={mem['SwapCached']}
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
          title="Slab"
          desc="In-kernel data structures which include the dentry and inode caches."
          color={'yellow'}
          pages={mem['Slab']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Page Tables"
          desc="Memory dedicated to the lowest level of page tables: This memory is used to manage virtual memory itself."
          color={'#DE8C2B'}
          pages={mem['PageTables']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Unaccounted for"
          desc="Memory not accounted for in memstat. It is probably non-slab memory used by the kernel, for example vmalloc."
          color={'grey'}
          pages={other_main}
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
       {this.props.showLRU ?
       <div style={{ height: this.props.height*0.5 }}>
        <MemoryUsageBarSegment
          title="Active Anonymous"
          desc="Anonymous (not file-backed) memory that is currently on the active LRU list: Memory of programs that has been accessed recently (hot)."
          color={'#ED1A25'}
          pages={mem['Active(anon)']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Inactive Anonymous"
          desc="Anonymous (not file-backed) memory that is currently on the inactive LRU list: Program memory that hasn't been accessed recently and is a candidate for swapping (cold)."
          color={'#FF6363'}
          pages={mem['Inactive(anon)']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Active File"
          desc="File-system backed memory that is currently on the active LRU list: This memory has been accessed recently (hot)."
          color={'#800D78'}
          pages={mem['Active(file)']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Inactive File"
          desc="File-system backed memory that is currently on the inactive LRU list: This memory hasn't been accessed recently and is a candidate for paging out (cold)."
          color={'#ED74E5'}
          pages={mem['Inactive(file)']}
          totalPages={mem['MemTotal']}
          {...this.props}
        />
        <MemoryUsageBarSegment
          title="Not on LRU lists"
          desc="This memory is not on any of the LRU lists. It is probably memory used by the kernel or is locked into RAM."
          color={'#494949'}
          pages={other_active}
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
       : null}
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
                 height: '100%',
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
