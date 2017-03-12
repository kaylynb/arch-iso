'use strict'

const nunjucks = require('nunjucks')
const shelljs = require('shelljs')
const co = require('co')
const path = require('path')
const fs = require('mz/fs')
const mkdirp = require('thenify')(require('mkdirp'))

const config = require(`./${process.argv[2]}`)

const child_process = require('child_process')

const exec = (cmd, opts) => {
	return new Promise((resolve, reject) => {
		const emitter = child_process.exec(cmd, opts, (err, stdout) => {
			if (err) {
				reject()
			} else {
				resolve(stdout.trim())
			}
		})

		emitter.stdout.pipe(process.stdout)
	})
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

		const buildName = `archlinux-isobuild-${Date.now()}`

		yield exec(`docker build --no-cache -t ${buildName} ${buildDirectory}`)
		yield exec(`docker run --privileged --rm -v ${path.resolve(__dirname, '../iso/')}:/archiso/out/ ${buildName} /bin/bash usr/sbin/build-iso.sh`)
		yield exec(`docker rmi ${buildName}`)
	} finally {
		if (buildDirectory) {
			console.log(`Removing build directory [${buildDirectory}]`)
			shelljs.rm('-rf', buildDirectory)
		}
	}
}).catch(err => {
	console.log('ERROR')
	console.log(err)
})
