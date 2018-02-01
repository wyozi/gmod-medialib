// This file builds medialib into a single file distributable
// Because medialib uses a hacky module system, this file is quite hacky as well
//
// NPM Requirements to run: luamin, q

// You can use following Git pre-commit hook to auto-build before commit
/*
#!/bin/sh

cd builder
nodejs build.js build
cd ..

OUT=$?
if [ $OUT -ne 0 ];then
	exit 1
fi

git add dist/*.lua
*/

process.chdir(".."); // We want to be at the addon root

var Q = require("q");

var buildNoGit = false;
if (process.argv.indexOf("--no-git") != -1) {
	buildNoGit = true;
}

if (process.argv.indexOf("build") == -1) {
	showHelp();
	process.exit(0);
}

function showHelp() {
	console.log("Usage: iojs build.js [build]");
	console.log("");
	console.log("Options:");
	console.log("--no-git	builds from workdir instead of HEAD");
}

// Initializes git repo and fetches HEAD Tree
function initGit() {
	/* TODO nodegit doesn't work, uhm

	var NodeGit;
	try {
		NodeGit = require("nodegit");
	}
	catch (e) {
		console.log("'nodegit' not found. Maybe you should use the --no-git option.");
		process.exit(1);
	}
	NodeGit.Repository.open(require("path").resolve(".")).then(function(repo) {
		return repo.head();
	}).then(function(headRef) {
		return repo.getCommit(headRef);
	}).then(function(commit) {
		return commit.getTree();
	}).then(function(tree) {
		HEADTree = tree;
		console.log("HEADTree retrivied");
	});*/
}

var fs = require("fs");
var exec = require("child_process").exec;
function getVersion() {
	var deferred = Q.defer();

	exec("git rev-parse HEAD", function(err, stdout, stderr) {
		if (err) deferred.reject(err);
		else     deferred.resolve("git@" + stdout.trim().substring(0, 8));
	});

	return deferred.promise;
}

function getBlob(path) {
	var deferred = Q.defer();

	if (!buildNoGit) {
		exec("git show :" + path, function(err, stdout, stderr) {
			if (err) deferred.reject(err);
			else     deferred.resolve(stdout);
		});
	}
	else {
		fs.readFile(path, {encoding: "utf8"}, function(err, data) {
			if (err) deferred.reject(err);
			else     deferred.resolve(data);
		});
	}

	return deferred.promise;
}

function readPathFiles(path) {
	var deferred = Q.defer();

	if (!buildNoGit) {
		exec("git ls-files -- " + path, function(err, stdout, stderr) {
			if (err) deferred.reject(err);
			else {
				var sedPath = path == "" ? "" : (path + "/");
				var files = stdout.split("\n").filter(function(rawFile) {
					return rawFile.indexOf(sedPath) != -1;
				}).map(function(rawFile) {
					return rawFile.replace(sedPath, "");
				});

				deferred.resolve(files);
			}
		});
	}
	else {
		fs.readdir(path, function(err, data) {
			if (err) deferred.reject(err);
			else     deferred.resolve(data);
		});
	}

	return deferred.promise;
}

// Blob starting from garrysmod/
// This does not use git at all
function getGmodBlob(path) {
	var deferred = Q.defer();

	fs.readFile("../../" + path, {encoding: "utf8"}, function(err, data) {
		if (err) deferred.reject(err);
		else     deferred.resolve(data);
	});

	return deferred.promise;
}

var luamin = require("luamin");
function minify(str) {
	return luamin.minify(str);
}

function build(shouldMinify, targetFile) {
	console.log("MediaLib build process started [shouldMinify = " + shouldMinify + "; Luamin v" + luamin.version + "; Git = " + !buildNoGit + "]");

	if (!buildNoGit) {
		initGit();
	}

	function finished(fragments) {
		console.log("MediaLib build process finished (fragment #" + fragments.length + ")");
		var finalCode = fragments.join("\n");
		if (shouldMinify) {
			finalCode = minify(finalCode);
		}
		fs.writeFileSync(targetFile, finalCode);
	}

	var loadedModules = {};
	function loadModule(mod, codePromise) {
		if (mod in loadedModules) {
			return Q([]);
		}
		loadedModules[mod] = true;

		if (!codePromise) {
			codePromise = getBlob("lua/medialib/" + mod + ".lua");
		}

		return Q(codePromise).fail(function(e) {
			throw new Error("Failed to load code");
		}).then(function(code) {
			// Check code for dependencies (declared as module.load statement)
			var deps = [];

			function checkDeps(code) {
				var re = /medialib\.load\s*\(\s*"([^"]*)"\s*\)/g;
				var match;
				while (match = re.exec(code)) {
					if (deps.indexOf(match[1]) != -1) continue;

					deps.push(match[1]);
				}
			}
			checkDeps(code);

			// Check code for folderIterators
			var fitPromises = [];

			var re = /medialib\.folderIterator\s*\(\s*"([^"]*)"\s*\)/g;
			var match;
			while (match = re.exec(code)) {
				var it = match[1];

				var promise = readPathFiles("lua/medialib/" + it).then(function(files) {
					return Q.all(files.map(function(file) {
						var path = it + "/" + file;
						return getBlob("lua/medialib/" + path).then(function(data) {
							checkDeps(data);
							return [path, data];
						});
					}));
				});

				fitPromises.push(promise);
			}

			var fragments = [];

			// Step 1. Make sure all folderIterators' deps are added to deps array
			// Step 2. Load all dependencies in order of insertion
			// Step 3. Add FolderIterator objects to fragments
			return Q.all(fitPromises).then(function(folderIterators) {
				var promise = deps.reduce(function(soFar, x) {
					return soFar.then(function(y) {
						return loadModule(x).then(function(xres) {
							return y.concat(xres);
						})
					})
				}, Q([]));

				return promise.then(function(arr) {
					fragments = fragments.concat(arr);
				}).then(function() { return folderIterators; });
			}).then(function(folderIterators) {
				folderIterators.forEach(function(arr) {
					arr.forEach(function(fitEl) {
						var minified = shouldMinify ? minify(fitEl[1]) : fitEl[1];
						fragments.push("medialib.FolderItems[" + JSON.stringify(fitEl[0]) + "] = " + JSON.stringify(minified) + "");
					});
				})
			}).then(function() {
				var minified = shouldMinify ? minify(code) : code;
				fragments.push("-- '" + mod + "'; CodeLen/MinifiedLen " + code.length + "/" + minified.length + "; Dependencies [" + deps + "]");

				// Add module placeholder, this is required for bundled modules that don't create the module themselves
				fragments.push("medialib.modulePlaceholder(" + JSON.stringify(mod) + ")");

				fragments.push("do");
				fragments.push(minified);
				fragments.push("end");

				return fragments;
			});
		}).fail(function(e) {
			if (e.message == "Failed to load code") {
				console.log("Warning: " + mod + " code not found. This message can be ignored if said module is an extension.");
				return [];
			}
			throw e;
		});
	}

	Q.spread([getBlob("lua/autorun/medialib.lua"), getVersion()], function(data, version) {
		data = data.replace("VERSION = \"local\"", "VERSION = \"" + version + "\"");
		data = data.replace("DISTRIBUTABLE = false", "DISTRIBUTABLE = true");
		data = shouldMinify ? minify(data) : data;

		data = "do\n" + data + "\nend\n";

		var fragments = [data];

		return loadModule("__loader", getBlob("lua/autorun/medialib_loader.lua")).then(function(fragz) {
			return fragments.concat(fragz);
		})
	}).done(function(fragments) {
		fragments = ["local medialib\n"].concat(fragments).concat("return medialib")
		finished(fragments);
	});
}

build(false, "dist/medialib.lua");
build(true, "dist/medialib.min.lua");
