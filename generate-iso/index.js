'use strict'

const nunjucks = require('nunjucks')
const shelljs = require('shelljs')
const co = require('co')
const path = require('path')
const fs = require('mz/fs')

const config = require('./vm.json')

const execStatus = (cmd, opts) => {
	return new Promise((resolve, reject) => {
		shelljs.exec(cmd, opts, (code, output) => {
			resolve({ code, output })
		})
	})
}

const exec = function * (cmd, opts) {
	const result = yield execStatus(cmd, opts)

	if (result.code !== 0)
		throw `Code: ${result.code}\nOutput: ${result.output}`

	return result.output.trim()
}

nunjucks.configure({
	autoescape: false,
	throwOnUndefined: true
})

let buildDirectory = undefined
const setBuildDirectory = function * () {
	buildDirectory = yield exec('mktemp -d /tmp/generate-isoXXXXXX', { silent: true })
	console.log(`Build directory created [${buildDirectory}]`)
}

const createBuild = function * () {
	yield fs.writeFile(
		path.resolve(buildDirectory, 'build-iso.sh'),
		nunjucks.render(
			path.resolve(__dirname, 'tpl/build-iso.sh'),
			config
		)
	)
}

const createInstall = function * () {
	yield fs.writeFile(
		path.resolve(buildDirectory, 'install.sh'),
		nunjucks.render(
			path.resolve(__dirname, 'tpl/install.sh'),
			config
		)
	)
}

const createDockerfile = function * () {
	yield fs.writeFile(
		path.resolve(buildDirectory, 'Dockerfile'),
		nunjucks.render(
			path.resolve(__dirname, 'tpl/Dockerfile'),
			config
		)
	)
}

co(function * () {
	try {
		yield setBuildDirectory()
		yield createBuild()
		yield createInstall()
		yield createDockerfile()
	} finally {
		if (buildDirectory) {
			// console.log(`Removing build directory [${buildDirectory}]`)
			// shelljs.rm('-rf', buildDirectory)
		}
	}
}).catch(err => {
	console.log('ERROR')
	console.log(err)
})
