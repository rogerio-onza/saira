'use strict';

const path = require('node:path');

// R and the app files are outside the archive, in app.asar.unpacked. Only the
// last path component is the archive: a folder such as "app.asar-tests"
// higher in the install path stays as it is. A development run has no
// archive, so its base stays.
function unpackedRoot(base, paths = path) {
  return paths.basename(base) === 'app.asar'
    ? paths.join(paths.dirname(base), 'app.asar.unpacked')
    : base;
}

module.exports = { unpackedRoot };
