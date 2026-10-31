// The Mapping filter follows a server patch of a card (SP-12): the real
// module-mapping.js runs on a small simulated DOM.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = process.argv[2];

const byId = new Map();
function node(id, classes, dataset) {
  const set = new Set(classes || []);
  const el = {
    id: id || '', hidden: false, textContent: '', dataset: dataset || {},
    children: [], parentElement: null,
    classList: {
      contains: c => set.has(c),
      add: (...cs) => cs.forEach(c => set.add(c)),
      remove: (...cs) => cs.forEach(c => set.delete(c)),
      toggle: (c, on) => { if (on === undefined) on = !set.has(c); on ? set.add(c) : set.delete(c); return on; }
    },
    append(...kids) { kids.forEach(k => { k.parentElement = el; el.children.push(k); }); return el; },
    // Supports '.a.b' (descendants) and ':scope > .a.b' (children).
    querySelectorAll(selector) {
      const direct = selector.startsWith(':scope > ');
      const need = selector.replace(':scope > ', '').split('.').filter(Boolean);
      const out = [];
      (function walk(parent) {
        parent.children.forEach(k => {
          if (need.every(c => k.classList.contains(c))) out.push(k);
          if (!direct) walk(k);
        });
      })(el);
      return out;
    },
    querySelector(selector) { return el.querySelectorAll(selector)[0] || null; }
  };
  if (id) byId.set(id, el);
  return el;
}

let mode = 'relevant';
const handlers = {}, messages = {};
const document = {
  getElementById: id => byId.get(id) || null,
  querySelector(selector) {
    return selector === 'input[name="mapping-mapped_filter"]:checked' ? { value: mode } : null;
  },
  addEventListener() {}
};
function jQuery() {
  return {
    on(event, selector, fn) {
      if (fn) handlers[event + '|' + selector] = fn; else handlers[event] = selector;
    },
    trigger() {}
  };
}
const context = {
  window: { jQuery }, document,
  Shiny: { addCustomMessageHandler: (name, fn) => { messages[name] = fn; }, setInputValue() {} },
  setTimeout: fn => fn()
};
vm.runInNewContext(fs.readFileSync(path.join(assets, 'module-mapping.js'), 'utf8'), context);
context.window.sairaModuleBehavior.mappingGrid();

const out = node('mapping-mapping_ui');
const grid = node('', ['mapping-card-grid']);
const group = node('', ['mapping-more-group'], { one: 'term', other: 'terms' })
  .append(node('', ['mapping-more-label']), node('', ['mapping-more-terms']));
const required = node('mapping-fieldcard_scientificName', ['field-card', 'field-unmapped', 'field-required-missing']);
const mapped = node('mapping-fieldcard_locality', ['field-card', 'field-mapped']);
const row = node('mapping-fieldcard_habitat', ['field-card', 'field-unmapped'], { collapse: 'true' });
const opened = node('mapping-fieldcard_eventRemarks', ['field-card', 'field-unmapped'], { collapse: 'true' });
out.append(grid.append(group, required, mapped, row, opened));

const render = () => handlers['shiny:value']({ target: { id: 'mapping-mapping_ui' } });
const pickFilter = value => {
  mode = value;
  handlers['change|.shiny-input-radiogroup'].call({ id: 'mapping-mapped_filter' });
};
const patch = (el, isMapped, state) => messages['saira-toggle-field-mapped'](
  { id: el.id, mapped: isMapped, state: state || '', badge: null }
);

// Pending: a card that gets its column leaves the screen.
mode = 'pending';
render();
assert.equal(required.hidden, false);
assert.equal(mapped.hidden, true);
patch(required, true);
assert.equal(required.hidden, true, 'a resolved card stays visible in Pending');
patch(required, false, 'field-required-missing');
assert.equal(required.hidden, false, 'a card that is pending again stays hidden in Pending');

// Mapped: a card that loses its column leaves the screen.
pickFilter('mapped');
assert.equal(mapped.hidden, false);
patch(mapped, false);
assert.equal(mapped.hidden, true, 'an unmapped card stays visible in Mapped');
patch(mapped, true);
assert.equal(mapped.hidden, false);

// Relevant: the rows collapse on the filter switch, never on a patch.
pickFilter('relevant');
assert.ok(row.classList.contains('field-card-collapsed'));
assert.equal(group.querySelector('.mapping-more-terms').textContent, 'habitat, eventRemarks');
opened.classList.remove('field-card-compact'); // the user opens the full card
patch(opened, false);
assert.equal(opened.classList.contains('field-card-compact'), false, 'a patch closed a card the user opened');
patch(row, true);
assert.ok(row.classList.contains('field-card-collapsed'), 'a row that gets a column stays a row (ADR-137)');
assert.equal(row.hidden, false);
patch(required, false, 'field-required-missing');
assert.equal(required.hidden, false);

// A new render, as after a language switch, applies the picked filter.
mode = 'pending';
render();
assert.equal(mapped.hidden, true);
assert.equal(row.classList.contains('field-card-collapsed'), false);
console.log('Mapping filter follows the card patches.');
