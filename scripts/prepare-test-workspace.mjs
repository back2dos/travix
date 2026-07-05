import { spawnSync } from 'node:child_process';
import { cp, mkdir, appendFile, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const repoRoot = process.env.GITHUB_WORKSPACE ?? process.cwd();
const runnerTemp = process.env.RUNNER_TEMP ?? join(repoRoot, '..', 'travix-test-parent');
const haxeVersion = process.env.HAXE_VERSION;
const githubEnv = process.env.GITHUB_ENV;

if (!haxeVersion) {
  console.error('HAXE_VERSION is required');
  process.exit(1);
}

const testWorkspace = join(runnerTemp, 'travix-test');
const hxmlFiles = [
  'ansi.hxml',
  'hx3compat.hxml',
  'hx4compat.hxml',
  'tink_chunk.hxml',
  'tink_cli.hxml',
  'tink_core.hxml',
  'tink_io.hxml',
  'tink_macro.hxml',
  'tink_priority.hxml',
  'tink_streams.hxml',
  'tink_stringly.hxml',
  'tink_syntaxhub.hxml',
  'tink_testrunner.hxml',
  'tink_unittest.hxml',
];

function run(cmd, args, cwd) {
  const result = spawnSync(cmd, args, {
    cwd,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

await mkdir(testWorkspace, { recursive: true });
await mkdir(join(testWorkspace, 'haxe_libraries'), { recursive: true });

await cp(join(repoRoot, 'tests'), join(testWorkspace, 'tests'), { recursive: true });
await cp(join(repoRoot, 'tests.hxml'), join(testWorkspace, 'tests.hxml'));

for (const file of hxmlFiles) {
  await cp(
    join(repoRoot, 'haxe_libraries', file),
    join(testWorkspace, 'haxe_libraries', file),
  );
}

run('lix', ['scope', 'create'], testWorkspace);
run('lix', ['install', 'haxe', haxeVersion], testWorkspace);
run('lix', ['dev', 'travix', repoRoot], testWorkspace);
run('lix', ['download'], testWorkspace);

const travixHxml = join(testWorkspace, 'haxe_libraries', 'travix.hxml');
const travixContent = await readFile(travixHxml, 'utf8');
if (!travixContent.includes('@run:')) {
  await writeFile(
    travixHxml,
    `# @run: haxelib run-dir travix ${repoRoot}\n${travixContent}`,
  );
}

if (githubEnv) {
  await appendFile(githubEnv, `TEST_WORKSPACE=${testWorkspace}\n`);
}

console.log(`Test workspace ready at ${testWorkspace}`);
