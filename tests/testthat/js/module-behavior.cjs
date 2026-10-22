const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = process.argv[2];

function filters(file, factory, ids) {
  const handlers = new Map(), values = new Map([[`#${ids[0]}`, 'Panthera'], [`#${ids[1]}`, ''], [`#${ids[2]}`, '15']]);
  const searches = [], lengths = [], draws = [];
  const document = {};
  function $(selector) {
    const element = {
      length: 1, 0: selector,
      off() { return element; },
      on(event, target, callback) { handlers.set(`${event}|${target}`, callback); return element; },
      closest() { return element; }, find() { return element; }, filter() { return element; },
      removeClass() { return element; }, addClass() { return element; },
      attr(name, value) { return arguments.length > 1 ? element : ''; },
      val(value) {
        if (arguments.length) { values.set(selector, value); return element; }
        return typeof selector === 'object' && selector !== document ? selector.value : values.get(selector);
      }
    };
    return element;
  }
  const table = {
    search(value) { searches.push(value); return table; },
    draw(value) { draws.push(value); return table; },
    column() { return table; }, off() { return table; }, on() { return table; },
    table() { return { container: () => ({}) }; }
  };
  table.page = () => table;
  table.page.len = function(value) { if (!arguments.length) return lengths.at(-1) || 15; lengths.push(value); return table; };
  const context = { window: {}, document, $, Shiny: { setInputValue() {} } };
  vm.runInNewContext(fs.readFileSync(path.join(assets, file), 'utf8'), context);
  assert.equal(typeof context.window.sairaModuleBehavior[factory], 'function');
  const config = factory === 'namesTableFilters' ?
    { searchId: ids[0], pageId: ids[2], sensitivityId: 'sensitivity' } :
    { searchId: ids[0], classId: ids[1], pageId: ids[2] };
  context.window.sairaModuleBehavior[factory](config, table);
  assert.ok(searches.includes('Panthera'), `${factory} applies the initial search`);
  const input = [...handlers.entries()].find(([key]) => key.startsWith('input') && key.endsWith(`|#${ids[0]}`));
  assert.ok(input, `${factory} binds search input`);
  input[1].call({ value: 'Felis' });
  assert.equal(searches.at(-1), 'Felis');
  const change = [...handlers.entries()].find(([key]) => key.startsWith('change') && key.endsWith(`|#${ids[2]}`));
  assert.ok(change, `${factory} binds page length`);
  change[1].call({ value: '50' });
  assert.equal(lengths.at(-1), 50);
  assert.ok(draws.length > 0);
}

filters('module-wiki.js', 'wikiTableFilters', ['wiki-search', 'wiki-class', 'wiki-page']);
filters('module-validate-names.js', 'namesTableFilters', ['names-search', 'names-class', 'names-page']);

const context = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(assets, 'module-utils-coords.js'), 'utf8'), context);
const zooms = [], events = new Map();
let width = 1024;
const map = { options: {}, getSize: () => ({ x: width }), setMinZoom: z => zooms.push(z), on: (event, fn) => events.set(event, fn) };
context.window.sairaModuleBehavior.leafletFillWorld({}).call(map);
assert.equal(map.options.maxBoundsViscosity, 1);
assert.equal(zooms.at(-1), 2);
width = 2048;
events.get('resize')();
assert.equal(zooms.at(-1), 3);
console.log('DataTables search/page ports and Leaflet resize behavior passed.');
