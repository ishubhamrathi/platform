const { spawn } = require('node:child_process');
const path = require('node:path');

const isWindows = process.platform === 'win32';
const script = isWindows ? 'gradlew.bat' : './gradlew';
const cwd = path.join(__dirname, '..', 'backend');

const child = spawn(script, ['bootRun'], { cwd, stdio: 'inherit' });

child.on('exit', (code) => process.exit(code ?? 0));
