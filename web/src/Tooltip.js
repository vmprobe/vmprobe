import React from 'react';
import ReactDOM from 'react-dom';
import PureComponent from 'react-pure-render/component';



let portalNode;
let lastPageX = 0;
let lastPageY = 0;

export default class Tooltip extends PureComponent {
  static defaultProps = {
    active: false,
    zIndex: 2147483647,
  }

  constructor(props) {
    super(props);

    this.state = {
      top: 0,
      left: 0,
    }
  }

  showTooltip(event) {
    //event.stopPropagation();

    if (!portalNode) {
      portalNode = document.createElement('div');
      document.body.appendChild(portalNode);
    }

    lastPageX = event.pageX;
    lastPageY = event.pageY;

    this.renderTip();
  }

  renderTip() {
    let style = {
      zIndex: this.props.zIndex,
    };

    let parentPos, mouseX, mouseY;

    if (this.parentElement) {
      parentPos = this.parentElement.getBoundingClientRect();

      mouseX = lastPageX - parentPos.left;
      mouseY = lastPageY - parentPos.top;
    }

    this.tipElement = ReactDOM.render(
      <span className="Tooltip-content" style={style}>
        {typeof(this.props.tip) === 'function' ? this.props.tip(mouseX, mouseY) : this.props.tip}
      </span>,
      portalNode);

    if (this.parentElement) {
      let tipPos = this.tipElement.getBoundingClientRect();

      let top = parentPos.top + parentPos.height + 2;
      let left = parentPos.left + (parentPos.width / 2) - (tipPos.width / 2);

      left = Math.max(left, 0);

      this.tipElement.style.top = `${top}px`;
      this.tipElement.style.left = `${left}px`;
    }
  }

  hideTooltip() {
    ReactDOM.unmountComponentAtNode(portalNode);
    this.tipElement = null;
  }

  render() {
    let parent = React.cloneElement(this.props.parent, {
                                      onMouseOver: this.showTooltip.bind(this),
                                      onMouseOut: this.hideTooltip.bind(this),
                                      ref: function(e) { this.parentElement = e }.bind(this),
                                    });


    if (this.tipElement && portalNode && this.parentElement) {
      this.renderTip();
    }

    return parent;
  }
}
