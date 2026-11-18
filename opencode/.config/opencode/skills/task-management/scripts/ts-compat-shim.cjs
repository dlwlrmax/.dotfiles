/**
 * Minimal TypeScript-compatible shim for ts-node 10.9.2.
 * TypeScript 7.0.2 (native) exposes no classic `ts.sys` API, which breaks ts-node.
 * This shim implements just enough of the TS API to run CommonJS .ts scripts.
 */
const fs = require('fs');
const path = require('path');
const { stripTypeScriptTypes } = require('node:module');

const ScriptTarget = {
  ES3: 0, ES5: 1, ES6: 2, ES2015: 2, ES2016: 3, ES2017: 4, ES2018: 5,
  ES2019: 6, ES2020: 7, ES2021: 8, ES2022: 9, ESNext: 99, Latest: 99,
};
const ModuleKind = { None: 0, CommonJS: 1, AMD: 2, UMD: 3, System: 4, ES2015: 5, ES2020: 6, ES2022: 7, ESNext: 99, Node16: 100, NodeNext: 199 };
const JsxEmit = { None: 0, Preserve: 1, React: 2, ReactNative: 3, ReactJSX: 4, ReactJSXDev: 5 };
const ModuleResolutionKind = { Classic: 1, Node10: 2, NodeJs: 2, Node16: 3, NodeNext: 99, Bundler: 100 };

const sys = {
  fileExists: (p) => { try { return fs.statSync(p).isFile(); } catch { return false; } },
  readFile: (p) => { try { return fs.readFileSync(p, 'utf8'); } catch { return undefined; } },
  writeFile: () => {},
  getCurrentDirectory: () => process.cwd(),
  getExecutingFilePath: () => __filename,
  resolvePath: (p) => path.resolve(p),
  newLine: '\n',
  useCaseSensitiveFileNames: true,
  directoryExists: (p) => { try { return fs.statSync(p).isDirectory(); } catch { return false; } },
  getDirectories: (p) => { try { return fs.readdirSync(p).filter((f) => fs.statSync(path.join(p, f)).isDirectory()); } catch { return []; } },
  readDirectory: (p) => { try { return fs.readdirSync(p); } catch { return []; } },
  realpath: (p) => fs.realpathSync(p),
  getEnvironmentVariable: (v) => process.env[v] || '',
  exit: (code) => process.exit(code),
};

function transpileModule(input, opts) {
  try {
    const js = stripTypeScriptTypes(input, { mode: 'strip' });
    const fileName = (opts && opts.fileName) || 'module.ts';
    const sourceMapText = JSON.stringify({
      version: 3,
      file: fileName,
      sources: [fileName],
      names: [],
      mappings: '',
    });
    return { outputText: js, diagnostics: [], sourceMapText };
  } catch (e) {
    return { outputText: input, diagnostics: [{ category: 1, code: 0, messageText: String(e), file: undefined, start: 0, length: 0 }], sourceMapText: undefined };
  }
}

function findConfigFile(searchPath, fileExists, configName) {
  return undefined;
}
function readConfigFile(fileName, readFile) {
  return { config: {}, error: undefined };
}
function parseJsonConfigFileContent(json, host, basePath, existingOptions, configFileName) {
  return { options: { target: ScriptTarget.ES5, module: ModuleKind.CommonJS }, fileNames: [], errors: [], raw: json };
}
function resolveConfigFileNames() { return []; }
function createProgram() {
  return { getCompilerOptions: () => ({ target: ScriptTarget.ES5, module: ModuleKind.CommonJS }), emit: () => undefined };
}

function createGetCanonicalFileName(useCaseSensitiveFileNames) {
  return useCaseSensitiveFileNames ? (f) => f : (f) => f.toLowerCase();
}

module.exports = {
  version: '4.6.0',
  sys,
  ScriptTarget,
  ModuleKind,
  JsxEmit,
  ModuleResolutionKind,
  transpileModule,
  transpile: (input) => stripTypeScriptTypes(input, { mode: 'strip' }),
  findConfigFile,
  readConfigFile,
  parseJsonConfigFileContent,
  createProgram,
  createSourceFile: () => ({ statements: [], text: '' }),
  createDocumentRegistry: () => ({
    acquireDocument: () => undefined,
    releaseDocument: () => undefined,
    acquireDocumentKey: () => 'shim',
    updateDocument: () => undefined,
  }),
  createLanguageService: () => ({
    getProgram: () => undefined,
    dispose: () => undefined,
  }),
  createGetCanonicalFileName,
  createModuleResolutionCache: () => ({}),
  resolveModuleName: () => ({ resolvedModule: undefined }),
  resolveModuleNameFromCache: () => undefined,
  resolveTypeReferenceDirective: () => ({ resolvedTypeReferenceDirective: undefined }),
  getPreEmitDiagnostics: () => [],
  flattenDiagnosticMessageText: (m) => (m && m.messageText) || String(m || ''),
  formatDiagnostics: () => '',
};
