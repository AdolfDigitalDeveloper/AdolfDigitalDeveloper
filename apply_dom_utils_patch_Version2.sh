#!/usr/bin/env bash
set -euo pipefail

# apply_dom_utils_patch.sh
# Script to move legacy files to legacy/ and write consolidated new files.
# Run from the repository root. Recommended: run on a new branch.
#
# Usage:
#   chmod +x apply_dom_utils_patch.sh
#   ./apply_dom_utils_patch.sh

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="legacy"
echo "Creating legacy backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/src/core" "${BACKUP_DIR}/src/ajax" || true

# Files we want to move to legacy if they exist
FILES_TO_MOVE=(
  "src/index.js"
  "src/core/dom-extensions.js"
  "src/ajax/fetch.js"
  "rollup.config.js"
  "src/core/bottom-sheet-base.js"
  "src/core/bottom-sheet.js"
)

for f in "${FILES_TO_MOVE[@]}"; do
  if [ -f "$f" ]; then
    dest="${BACKUP_DIR}/${f}.old"
    mkdir -p "$(dirname "$dest")"
    echo "Moving existing $f -> $dest"
    # prefer git mv when available and repo is a git repo
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git mv -f "$f" "$dest" || mv -f "$f" "$dest"
    else
      mv -f "$f" "$dest"
    fi
  else
    echo "File $f not found; a legacy copy will be created with stored old content."
  fi
done

echo "Writing new/updated files..."

# package.json
cat > package.json <<'EOF'
{
  "name": "dom-utils-library",
  "version": "0.1.0",
  "description": "Lightweight modern DOM utilities library (formerly $hybrid). Encadenable API + modular utilities.",
  "main": "dist/index.cjs.js",
  "module": "dist/index.esm.js",
  "unpkg": "dist/index.umd.js",
  "exports": {
    ".": {
      "import": "./dist/index.esm.js",
      "require": "./dist/index.cjs.js",
      "default": "./dist/index.cjs.js"
    },
    "./bottom-sheet": {
      "import": "./dist/bottom-sheet.esm.js",
      "require": "./dist/bottom-sheet.cjs.js",
      "default": "./dist/bottom-sheet.cjs.js"
    }
  },
  "sideEffects": false,
  "scripts": {
    "build": "rollup -c",
    "dev": "rollup -c -w",
    "lint": "eslint \"src/**/*.js\"",
    "format": "prettier --write \"src/**/*.js\"",
    "test": "uvu -r esm test",
    "prepare": "npm run build"
  },
  "files": [
    "dist",
    "src"
  ],
  "repository": {
    "type": "git",
    "url": "git+https://github.com/your-org/dom-utils-library.git"
  },
  "keywords": [
    "dom",
    "utilities",
    "drag",
    "observer",
    "lightweight"
  ],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "rollup": "^3.0.0",
    "rollup-plugin-terser": "^7.0.2",
    "@rollup/plugin-commonjs": "^24.0.0",
    "@rollup/plugin-node-resolve": "^15.0.0",
    "eslint": "^8.0.0",
    "prettier": "^2.0.0",
    "uvu": "^0.5.0"
  }
}
EOF

# rollup.config.js
cat > rollup.config.js <<'EOF'
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import { terser } from 'rollup-plugin-terser';

/*
  Build config:
  - dist/index.esm.js  (ESM build)
  - dist/index.cjs.js  (CJS build)
  - dist/index.umd.js  (UMD minified)
  - dist/bottom-sheet.esm.js (ESM chunk for bottom-sheet)
  - dist/bottom-sheet.cjs.js (CJS chunk for bottom-sheet)
*/
const input = {
  main: 'src/index.js',
  'bottom-sheet': 'src/core/bottom-sheet.js'
};

export default [
  {
    input,
    external: [],
    plugins: [resolve(), commonjs()],
    output: [
      {
        entryFileNames: (chunkInfo) => (chunkInfo.name === 'main' ? 'index.esm.js' : '[name].esm.js'),
        dir: 'dist',
        format: 'esm',
        sourcemap: true,
        preserveEntrySignatures: 'strict'
      },
      {
        entryFileNames: (chunkInfo) => (chunkInfo.name === 'main' ? 'index.cjs.js' : '[name].cjs.js'),
        dir: 'dist',
        format: 'cjs',
        sourcemap: true,
        exports: 'named',
        preserveEntrySignatures: 'strict'
      }
    ],
    preserveEntrySignatures: 'strict'
  },
  {
    input: 'src/index.js',
    plugins: [resolve(), commonjs(), terser()],
    output: {
      file: 'dist/index.umd.js',
      format: 'umd',
      name: 'DOMUtilsLibrary',
      sourcemap: true
    }
  }
];
EOF

# src/index.js (new consolidated entry)
mkdir -p src
cat > src/index.js <<'EOF'
// index.js - Central exports (static imports for bundlers)
// Export core re-exports and components + ajax + new helpers

// Re-export core modules for direct imports
export * from './core/dom.js';
export * from './core/events.js';
export * from './core/dom-helpers-extended.js';
export * from './core/event-helpers.js';

// Re-export UI modules (allow direct import { Modal } from 'dom-utils-library')
export * from './modules/modal.js';
export * from './modules/tooltip.js';
export * from './modules/tabs.js';

// Re-export AJAX and animations/reactive modules
export * from './modules/ajax.js';
export * from './animations/animate.js';
export * from './reactive/signals.js';

// Static imports to build the default/root object for the default export
import * as DOMCore from './core/dom.js';
import * as EventsCore from './core/events.js';
import * as DomExt from './core/dom-helpers-extended.js';
import * as EventsExt from './core/event-helpers.js';

import * as ModalModule from './modules/modal.js';
import * as TooltipModule from './modules/tooltip.js';
import * as TabsModule from './modules/tabs.js';

import * as AjaxModule from './modules/ajax.js';
import * as AnimModule from './animations/animate.js';
import * as Reactive from './reactive/signals.js';

// Default/root export (namespaced, predictable)
const DOMUtilsLibrary = {
  // Core helpers
  ...DOMCore,
  ...EventsCore,

  // Extended DOM helpers namespace
  dom: {
    ...DomExt
  },

  // Extra event helpers
  events: {
    ...EventsExt
  },

  // Components as constructors/classes (preserve names)
  Modal: ModalModule.Modal,
  Tooltip: TooltipModule.Tooltip,
  Tabs: TabsModule.Tabs,

  // AJAX namespace
  ajax: {
    ...AjaxModule
  },

  // Animations namespace
  anim: {
    ...AnimModule
  },

  // Reactive namespace
  reactive: {
    ...Reactive
  }
};

export default DOMUtilsLibrary;
export { DOMUtilsLibrary };
EOF

# src/ajax/index.js (compat adapter)
mkdir -p src/ajax
cat > src/ajax/index.js <<'EOF'
// Compatibility re-export for ajax APIs (consolidated)
// This file keeps backwards-compatible import path `src/ajax` while delegating to the new modules/ajax.js

export * from '../modules/ajax.js';
export { default } from '../modules/ajax.js';
EOF

# src/core/dom-extensions.js (new extended version)
mkdir -p src/core
cat > src/core/dom-extensions.js <<'EOF'
// src/core/dom-extensions.js
// Extend DOMUtilsCore prototype with chainable DOM helpers, event helpers, and animation/reactive integrations.

import DOMUtilsCore from './wrapper.js';
import {
  append as appendHelper,
  prepend as prependHelper,
  before as beforeHelper,
  after as afterHelper,
  css as cssHelper,
  position as positionHelper,
  offset as offsetHelper,
  clone as cloneHelper
} from './dom-helpers-extended.js';

import {
  clickOutside as clickOutsideHelper,
  longPress as longPressHelper
} from './event-helpers.js';

import {
  animate as animateHelper,
  fadeIn as fadeInHelper,
  fadeOut as fadeOutHelper
} from '../animations/animate.js';

// WeakMap to store attached listener cleanup fns per node
const NODE_LISTENERS = new WeakMap();

function ensureNodeListeners(node) {
  let m = NODE_LISTENERS.get(node);
  if (!m) {
    m = { clickOutside: [], longPress: [] };
    NODE_LISTENERS.set(node, m);
  }
  return m;
}

function getNodesFromInstance(inst) {
  return Array.isArray(inst.nodes) ? inst.nodes : [];
}

// ----------------------
// DOM helpers (chainable)
// ----------------------
if (typeof DOMUtilsCore !== 'undefined') {
  // Append content to each matched node
  DOMUtilsCore.prototype.append = function (content) {
    this.each((el) => appendHelper(el, content));
    return this;
  };

  // Prepend content to each matched node
  DOMUtilsCore.prototype.prepend = function (content) {
    this.each((el) => prependHelper(el, content));
    return this;
  };

  // Insert content before the first matched node (mirrors Element.insertBefore semantics)
  DOMUtilsCore.prototype.before = function (content) {
    const nodes = getNodesFromInstance(this);
    if (!nodes.length) return this;
    // insert before the first node
    beforeHelper(nodes[0], content);
    return this;
  };

  // Insert content after the first matched node
  DOMUtilsCore.prototype.after = function (content) {
    const nodes = getNodesFromInstance(this);
    if (!nodes.length) return this;
    afterHelper(nodes[0], content);
    return this;
  };

  /**
   * css(propOrObj[, value])
   * - getter: css('color') -> returns computed style of first node
   * - setter: css('color', 'red') or css({ color: 'red' }) -> sets for all nodes and returns this
   */
  DOMUtilsCore.prototype.css = function (propOrObj, value) {
    const first = this.get(0);
    if (!first) return this;
    // Getter
    if (typeof propOrObj === 'string' && value === undefined) {
      return cssHelper(first, propOrObj);
    }
    // Setter
    this.each((el) => cssHelper(el, propOrObj, value));
    return this;
  };

  // position() -> returns position for first node
  DOMUtilsCore.prototype.position = function () {
    const el = this.get(0);
    if (!el) return null;
    return positionHelper(el);
  };

  // offset() -> returns document offset for first node
  DOMUtilsCore.prototype.offset = function () {
    const el = this.get(0);
    if (!el) return null;
    return offsetHelper(el);
  };

  // clone(options) -> returns a new DOMUtilsCore wrapping clones
  DOMUtilsCore.prototype.clone = function (options = {}) {
    const clones = getNodesFromInstance(this).map((el) => cloneHelper(el, options));
    return new DOMUtilsCore(clones);
  };

  // ----------------------
  // Event helpers (attach/detach)
  // ----------------------

  /**
   * clickOutside(handler, options)
   * - attaches a clickOutside handler for each node in the collection
   * - stores cleanup functions per node so they can be removed with offClickOutside()
   * - returns this for chaining
   */
  DOMUtilsCore.prototype.clickOutside = function (handler, options = {}) {
    if (typeof handler !== 'function') return this;
    this.each((el) => {
      const off = clickOutsideHelper(el, handler, options);
      const store = ensureNodeListeners(el);
      store.clickOutside.push(off);
    });
    return this;
  };

  /**
   * offClickOutside()
   * - removes stored clickOutside handlers for each node
   */
  DOMUtilsCore.prototype.offClickOutside = function () {
    this.each((el) => {
      const store = NODE_LISTENERS.get(el);
      if (!store || !store.clickOutside) return;
      store.clickOutside.forEach((offFn) => {
        try { offFn && offFn(); } catch (_) {}
      });
      store.clickOutside = [];
    });
    return this;
  };

  /**
   * longPress(handler, options)
   * - attaches longPress behavior for each node and stores off fns
   */
  DOMUtilsCore.prototype.longPress = function (handler, options = {}) {
    if (typeof handler !== 'function') return this;
    this.each((el) => {
      const off = longPressHelper(el, handler, options);
      const store = ensureNodeListeners(el);
      store.longPress.push(off);
    });
    return this;
  };

  /**
   * offLongPress()
   * - removes stored longPress handlers for each node
   */
  DOMUtilsCore.prototype.offLongPress = function () {
    this.each((el) => {
      const store = NODE_LISTENERS.get(el);
      if (!store || !store.longPress) return;
      store.longPress.forEach((offFn) => {
        try { offFn && offFn(); } catch (_) {}
      });
      store.longPress = [];
    });
    return this;
  };

  // ----------------------
  // Animations
  // ----------------------

  /**
   * animate(keyframes, options)
   * - returns a Promise that resolves when all animations finish (array of Animation/results)
   * - if you prefer fire-and-forget, call .animate(...).then(() => {}) or simply ignore the promise
   */
  DOMUtilsCore.prototype.animate = function (keyframes, options = {}) {
    const nodes = getNodesFromInstance(this);
    if (!nodes.length) return Promise.resolve([]);
    const promises = nodes.map((el) => {
      try {
        return animateHelper(el, keyframes, options);
      } catch (err) {
        return Promise.reject(err);
      }
    });
    return Promise.all(promises);
  };

  DOMUtilsCore.prototype.fadeIn = function (duration = 300) {
    const nodes = getNodesFromInstance(this);
    if (!nodes.length) return Promise.resolve([]);
    return Promise.all(nodes.map((el) => fadeInHelper(el, duration)));
  };

  DOMUtilsCore.prototype.fadeOut = function (duration = 300) {
    const nodes = getNodesFromInstance(this);
    if (!nodes.length) return Promise.resolve([]);
    return Promise.all(nodes.map((el) => fadeOutHelper(el, duration)));
  };

  // convenience async aliases for chainability where user wants to await:
  // DOMUtilsLibrary('.el').fadeInAsync(200).then(...)
  DOMUtilsCore.prototype.fadeInAsync = DOMUtilsCore.prototype.fadeIn;
  DOMUtilsCore.prototype.fadeOutAsync = DOMUtilsCore.prototype.fadeOut;
}

export default DOMUtilsCore;