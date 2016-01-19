import React from 'react';
import PureComponent from 'react-pure-render/component';

import { DragSource } from 'react-dnd';
import DragTypes from './DragTypes';

const snapshotDragSource = {
  beginDrag(props) {
    return {
      handleDrop: props.handleDrop,
    };
  }
};

class SnapshotDraggable extends PureComponent {
  render() {
    const { isDragging, connectDragSource } = this.props;
    return connectDragSource(
      <span style={{cursor: 'move', opacity: isDragging ? 0.5 : 1}}>
        <span className="glyphicon glyphicon-film" ariaHidden="true" />
        &nbsp;
        {this.props.filename}
      </span>
    );
  }
}

function collect(connect, monitor) {
  return {
    connectDragSource: connect.dragSource(),
    isDragging: monitor.isDragging()
  };
}

export default DragSource(DragTypes.SNAPSHOT, snapshotDragSource, collect)(SnapshotDraggable);
