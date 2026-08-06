const { spawn } = require('node:child_process');
const path = require('node:path');

const cwd = path.join(__dirname, '..', 'frontend');

const child = spawn('npm', ['run', 'dev'], { cwd, stdio: 'inherit', shell: process.platform === 'win32' });

child.on('exit', (code) => process.exit(code ?? 0));
