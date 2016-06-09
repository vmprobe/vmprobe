/*
This is a re-implementation of react's update function (https://facebook.github.io/react/docs/update.html)
with the following differences:

  * Simple recursive implementation without dependencies
  * Implements the $unset command which react refuses to merge (https://github.com/facebook/react/pull/2362/)
  * $unshift doesn't reverse the list (works like perl's unshift)
  * Supports auto-vivification: https://en.wikipedia.org/wiki/Autovivification
*/


function shallowCopyObject(x) {
  return Object.assign(new x.constructor(), x);
}

function shallowCopyArray(x) {
    return x.concat();
}


export default function update(view, upd) {
  if (typeof(upd) !== 'object') throw(new Error("update is not an object"));

  // Process commands:

  if (upd.hasOwnProperty('$set')) {
    return upd['$set'];
  }

  if (upd.hasOwnProperty('$unset')) {
    if (view === undefined) view = {};

    if (typeof(view) !== 'object') throw(new Error("view is not an object in unset"));

    let new_view = shallowCopyObject(view);
    delete new_view[upd['$unset']];

    return new_view;
  }

  if (upd.hasOwnProperty('$merge')) {
    if (view === undefined) view = [];

    if (typeof(view) !== 'object') throw(new Error("view is not an object in merge"));
    if (typeof(upd) !== 'object') throw(new Error("update is not an object in merge"));

    let new_view = shallowCopyObject(view);

    Object.assign(new_view, upd['$merge']);

    return new_view;
  }

  if (upd.hasOwnProperty('$push')) {
    if (view === undefined) view = [];

    if (!Array.isArray(view)) throw(new Error("view is not an array in push"));
    if (!Array.isArray(upd['$push'])) throw(new Error("update is not an array in push"));

    let new_view = shallowCopyArray(view);

    for (let e of upd['$push']) {
      new_view.push(e);
    }

    return new_view;
  }

  if (upd.hasOwnProperty('$unshift')) {
    if (view === undefined) view = [];

    if (!Array.isArray(view)) throw(new Error("view is not an array in unshift"));
    if (!Array.isArray(upd['$unshift'])) throw(new Error("update is not an array in unshift"));

    let new_view = shallowCopyArray(view);

    for (let e of upd['$unshift'].reverse()) {
      new_view.unshift(e);
    }

    return new_view;
  }

  if (upd.hasOwnProperty('$splice')) {
    if (view === undefined) view = [];

    if (!Array.isArray(view)) throw(new Error("view is not an array in splice"));
    if (!Array.isArray(upd['$splice'])) throw(new Error("update is not an array in splice"));

    let new_view = shallowCopyArray(view);

    for (let s of upd['$splice']) {
      if (!Array.isArray(s)) throw(new Error("update element is not an array"));
      new_view.splice.apply(new_view, s);
    }

    return new_view;
  }


  // Recurse to handle nested commands in upd:

  if (view === undefined) view = {};

  if (Array.isArray(view)) {
    let output = shallowCopyArray(view);

    for (let key in upd) {
        let int = parseInt(key);
        if (key != int) throw(new Error("non-numeric key in array update")); // deliberate != instead of !==
        output[int] = update(output[int], upd[key]);
    }

    return output;
  } else if (typeof(view) === 'object') {
    let output = shallowCopyObject(view);

    for (let key in upd) {
        output[key] = update(output[key], upd[key]);
    }

    return output;
  }

  throw(new Error("view not an array or hash"));
}
