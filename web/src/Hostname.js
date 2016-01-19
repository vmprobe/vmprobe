import React, { PropTypes } from 'react';
import PureComponent from 'react-pure-render/component';

import { DropTarget } from 'react-dnd';
import DragTypes from './DragTypes';


const hostnameDragTarget = {
  drop(props, monitor) {
    console.log("DROPPED!!!");
    console.log(monitor.getItem());
    console.log(props);
    monitor.getItem().handleDrop(props.hostname);
  }
};

const propTypes = {
  hostname: PropTypes.string.isRequired,
};

class Hostname extends PureComponent {
  render() {
    const { accepts, isOver, canDrop, connectDropTarget, lastDroppedItem } = this.props;
    const isActive = isOver && canDrop;

    let border;
    if (isActive) {
      border = '1px dashed #d40000';
    } else if (canDrop) {
      border = '1px dashed black';
    }

    return connectDropTarget(
      <div style={{ border }}>
        {this.props.hostname}
      </div>
    );
  }
}

Hostname.propTypes = propTypes;

function collect(connect, monitor) {
  return {
    connectDropTarget: connect.dropTarget(),
    isOver: monitor.isOver(),
    canDrop: monitor.canDrop(),
  };
}

export default DropTarget([DragTypes.SNAPSHOT], hostnameDragTarget, collect)(Hostname);
