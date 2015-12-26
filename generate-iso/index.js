'use strict'

const nunjucks = require('nunjucks')
const shelljs = require('shelljs')
const co = require('co')
const path = require('path')
const fs = require('mz/fs')
const mkdirp = require('thenify')(require('mkdirp'))

const config = require(`./${process.argv[2]}`)

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

const renderTpl = function * (filePath) {
	yield mkdirp(path.resolve(buildDirectory, path.dirname(filePath)))

	yield fs.writeFile(
		path.resolve(buildDirectory, filePath),
		nunjucks.render(
			path.resolve(__dirname, path.join('tpl', filePath)),
			config
		)
	)
}

co(function * () {
	try {
		yield setBuildDirectory()
		shelljs.cp('-R', path.resolve(__dirname, 'isofiles/*'), path.join(buildDirectory, 'isofiles/'))
		yield renderTpl('build-iso.sh')
		yield renderTpl('isofiles/root/install.sh')
		yield renderTpl('isofiles/root/chroot-install.sh')
		yield renderTpl('Dockerfile')
		yield renderTpl('isofiles/etc/vconsole.conf')
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
