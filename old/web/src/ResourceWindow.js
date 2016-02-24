import React from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from './Tooltip';
import Draggable from 'react-draggable';
import { Resizable, ResizableBox } from 'react-resizable';



export class ResourceWindow extends PureComponent {
  static defaultProps = {
    closeable: true,
  };

  constructor(props) {
    super(props);

      let child = React.Children.only(this.props.children);

    this.state = {
      width: child.props['defaultWidth'] || 600,
      height: child.props['defaultHeight'] || 400,
      zIndex: this.props.getNextWindowZIndex(),

      minimised: false,
    };
  }

  render() {
    let orig_child = React.Children.only(this.props.children);

    let child = React.cloneElement(orig_child,
                                   { windowWidth: this.state.width, windowHeight: this.state.height-20, windowZIndex: this.state.zIndex });

    let windowCloseButton;

    if (this.props.closeable) {
      windowCloseButton = <span className="glyphicon glyphicon-remove-sign"
                                ariaHidden="true"
                                onClick={this.closeWindow.bind(this)}
                          />;
    }

    let error_indicator;

    if (child.props.errors) {
      let error_messages = [];

      let num_to_display = 5;

      for (let i = child.props.errors.length - 1; i >= Math.max(0, child.props.errors.length - num_to_display); i--) {
        error_messages.push(
          <div key={i}>
            {i+1}: {child.props.errors[i]}
          </div>
        );
      }

      error_indicator = (
        <Tooltip
          parent={
            <span style={{ color: 'red', align: 'right' }}>
              {child.props.errors.length}
              <span className="glyphicon glyphicon-fire" ariaHidden="true" />
            </span>
          }
          tip={
            <div style={{ color: 'red' }}>
              {error_messages}
              {child.props.errors.length > num_to_display ? (child.props.errors.length - num_to_display) + " more..." : null}
            </div>
          }
        />
      );
    }


    let job_display;

    if (child.props.jobs) {
      let active_jobs = [];

      for (let job_id of Object.keys(child.props.jobs)) {
        let job = child.props.jobs[job_id];

        active_jobs.push(
          <Tooltip
            key={job_id}
            parent={
              <span style={{ color: '#088024' }} className="glyphicon glyphicon-transfer" ariaHidden="true" />
            }
            tip={
              <div>
                <div>{job.type}</div>
                <div>{job.desc}</div>
              </div>
            }
          />
        );
      }

      job_display = <div>{active_jobs}</div>;
    }


    return (
      <Draggable handle=".handle" onStart={this.foreground.bind(this)}>
        <div className="resourceWindow" style={{zIndex: this.state.zIndex, width: this.state.width}}>

          <div onClick={this.foreground.bind(this)} onDoubleClick={this.toggleMinimised.bind(this)} className="resourceWindowHeader handle">
            <div className="title handle">{typeof(child.props.windowTitle) === 'function' ? child.props.windowTitle(child) : child.props.windowTitle}</div>
            {job_display}
            <div className="controls">
              {error_indicator}
              <span style={{ marginLeft: 20 }} className={"glyphicon " + (this.state.minimised ? "glyphicon-collapse-down" : "glyphicon-collapse-up")}
                    ariaHidden="true"
                    onClick={this.toggleMinimised.bind(this)}
              />
              {windowCloseButton}
            </div>
          </div>

          <div className="resourceWindowBody" style={{ display: (this.state.minimised ? 'none' : 'block') }}>
            <ResizableBox width={this.state.width} height={this.state.height} className="resourceWindowBodyResizable" onResize={this.onResize.bind(this)}>
              <div style={{ width:this.state.width, height: this.state.height }}>
                {child}
              </div>
            </ResizableBox>
          </div>

        </div>
      </Draggable>
    );
  }

  onResize(event, {element, size}) {
    this.setState({
      width: size.width,
      height: size.height,
      zIndex: this.props.getNextWindowZIndex(),
    });
  };

  foreground(event, ui) {
    this.setState({
      zIndex: this.props.getNextWindowZIndex(),
    });
  }

  toggleMinimised() {
    this.setState({
      minimised: !this.state.minimised,
      zIndex: this.props.getNextWindowZIndex(),
    });
  }

  closeWindow() {
    this.props.vmprobe_console.sendMsg({
      close: this.props.resource_id,
    });
  }
}
