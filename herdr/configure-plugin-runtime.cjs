#!/usr/bin/env node
'use strict';

// Herdr launched from a GUI can inherit only the system PATH. Its runtime
// commands bypass shell startup files, so use a login shell for these plugins.
// Patch manifests, not plugins.json: Herdr re-reads manifests on every action.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const registryPath = process.argv[2] || path.join(
  process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config'),
  'herdr', 'plugins.json',
);
const shell = process.argv[3] || process.env.SHELL || '/bin/sh';
if (!path.isAbsolute(shell) || !['sh', 'bash', 'zsh', 'dash', 'ksh'].includes(path.basename(shell))) {
  throw new Error(`A POSIX-compatible login shell is required: ${shell}`);
}
fs.accessSync(shell, fs.constants.X_OK);

const marker = 'herdr-dotfiles-plugin';
const prefix = [shell, '-lc', 'exec "$@"', marker];
const plugins = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const updates = [];
for (const id of ['hhdebb.herdr-radar', 'numbered.ports']) {
  const plugin = plugins.find((entry) => entry.plugin_id === id);
  if (!plugin) throw new Error(`Plugin is not installed: ${id}`);
  const filename = plugin.manifest_path;
  const original = fs.readFileSync(filename, 'utf8');
  let count = 0;
  let updated = original.replace(
    /^([\t ]*)command[\t ]*=[\t ]*(\[[^\n]*\])([\t ]*(?:#.*)?)$/gm,
    (_, indent, encoded, suffix) => {
      count++;
      let command = JSON.parse(encoded);
      if (!Array.isArray(command) || !command.length || command.some((arg) => typeof arg !== 'string')) {
        throw new Error(`Invalid command in ${filename}`);
      }
      if (command[1] === '-lc' && command[2] === 'exec "$@"' && command[3] === marker) {
        command = command.slice(4);
      }
      return `${indent}command = ${JSON.stringify([...prefix, ...command])}${suffix}`;
    },
  );
  if (!count || count !== (original.match(/^\s*command\s*=/gm) || []).length) {
    throw new Error(`Unsupported command format in ${filename}; no manifests changed`);
  }
  if (id === 'numbered.ports' && !original.split(/^\[\[/m).some(
    (section) => section.startsWith('startup]]') && section.includes('"ensure-watch"'),
  )) {
    updated += '\n# Start badges for existing panes too, including restored sessions.\n' +
      '[[startup]]\ncommand = ' + JSON.stringify([...prefix, './herdr-ports', 'ensure-watch']) + '\n';
  }
  if (id === 'numbered.ports' && !original.split(/^\[\[/m).some(
    (section) => section.startsWith('actions]]') && /^id\s*=\s*"ensure-watch"$/m.test(section),
  )) {
    updated += '\n[[actions]]\nid = "ensure-watch"\ntitle = "Start ports watcher"\n' +
      'command = ' + JSON.stringify([...prefix, './herdr-ports', 'ensure-watch']) + '\n';
  }
  updates.push({ id, filename, original, updated });
}

for (const { id, filename, original, updated } of updates) {
  if (updated !== original) {
    const backup = `${filename}.before-dotfiles-runtime`;
    if (!fs.existsSync(backup)) fs.copyFileSync(filename, backup, fs.constants.COPYFILE_EXCL);
    const temporary = `${filename}.${process.pid}.tmp`;
    fs.writeFileSync(temporary, updated, { flag: 'wx', mode: fs.statSync(filename).mode & 0o777 });
    fs.renameSync(temporary, filename);
  }
  console.log(`  runtime  ${id} (${shell} login shell)`);
}
