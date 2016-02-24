import React from 'react';
import PureComponent from 'react-pure-render/component';

import Tooltip from './Tooltip';


export default class TooltipSame extends PureComponent {
  render() {
    return (
      <Tooltip
        parent={<span>{this.props.item}</span>}
        tip={<span>{this.props.item}</span>}
      />
    );
  }
}
