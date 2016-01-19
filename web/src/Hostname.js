import React, { PropTypes } from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from './Tooltip';

import { DropTarget } from 'react-dnd';
import DragTypes from './DragTypes';


const hostnameDragTarget = {
  drop(props, monitor) {
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

    let border, backgroundColor;
    if (isActive) {
      border = '2px dashed #d40000';
      backgroundColor = '#fdd';
    } else if (canDrop) {
      border = '2px dashed black';
    }

    return connectDropTarget(
      <div style={{ border, backgroundColor }}>
        <Tooltip tip={this.props.hostname} parent={
          <span>
            <span className="glyphicon glyphicon-globe" ariaHidden="true" />
            &nbsp;
            {this.props.hostname}
          </span>
        }/>
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
