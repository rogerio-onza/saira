// The upload observes only its own progress bars (SP-14): the real
// upload-dropzone.js runs on a small simulated DOM.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = process.argv[2];

const observed = [];
class MutationObserver {
  constructor(callback) { this.callback = callback; }
  observe(target) { observed.push({ target, fire: () => this.callback([]) }); }
}

function upload(id) {
  const bar = { textContent: '' };
  const input = { type: 'file', id, files: [], addEventListener() {} };
  const dropzone = {
    dataset: {}, classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
    querySelector: () => null, appendChild() {}, addEventListener() {}
  };
  const section = {
    querySelector(selector) {
      if (selector.includes('progress-bar')) return bar;
      if (selector.includes('input-group')) return { remove() {} };
      if (selector.includes("input[type='file']")) return input;
      return null;
    },
    querySelectorAll: selector => (selector === '.upload-dropzone' ? [dropzone] : [])
  };
  dropzone.closest = selector => (selector === '.upload-section' ? section : null);
  input.closest = dropzone.closest;
  return { bar, input, dropzone };
}

const home = upload('upload-file');
const modal = upload('mapping-import_template_file');
const pageDropzones = [home.dropzone];
const queries = [];
const handlers = {}, messages = {};
const document = {
  readyState: 'complete', body: {},
  querySelectorAll(selector) {
    queries.push(selector);
    if (selector === '.upload-dropzone') return pageDropzones;
    if (selector.includes('progress-bar')) return [home.bar, modal.bar];
    return [];
  },
  addEventListener() {}
};
const context = {
  window: {
    Shiny: { addCustomMessageHandler: (name, fn) => { messages[name] = fn; } },
    jQuery: () => ({ on: (event, fn) => { handlers[event] = fn; } })
  },
  document, MutationObserver,
  setTimeout: fn => fn()
};
vm.runInNewContext(fs.readFileSync(path.join(assets, 'upload-dropzone.js'), 'utf8'), context);

assert.equal(home.dropzone.dataset.dropzoneBound, 'true', 'the Home dropzone is bound at start');
assert.deepEqual(observed.map(o => o.target), [home.bar], 'only the upload bar is observed');

// The modal dropzone arrives with its file input.
handlers['shiny:bound']({ bindingType: 'input', target: { type: 'text', closest: () => null } });
assert.equal(modal.dropzone.dataset.dropzoneBound, undefined);
handlers['shiny:bound']({ bindingType: 'input', target: modal.input });
assert.equal(modal.dropzone.dataset.dropzoneBound, 'true', 'the modal dropzone is bound');
assert.deepEqual(observed.map(o => o.target), [home.bar, modal.bar]);

// The label follows the language, and each bar swaps Shiny's text.
messages['saira-upload-complete-label']({ label: 'Envio concluído' });
modal.bar.textContent = 'Upload complete';
observed[1].fire();
assert.equal(modal.bar.textContent, 'Envio concluído');
messages['saira-upload-complete-label']({ label: 'Upload complete' });
home.bar.textContent = 'Upload complete';
observed[0].fire();
assert.equal(home.bar.textContent, 'Upload complete');

// A bind of another input does not scan the page for dropzones.
const scans = queries.filter(q => q === '.upload-dropzone').length;
handlers['shiny:bound']({ bindingType: 'input', target: { type: 'select-one', closest: () => null } });
assert.equal(queries.filter(q => q === '.upload-dropzone').length, scans);
console.log('Upload observes only its progress bars.');
