'use strict'

const nunjucks = require('nunjucks')
const shelljs = require('shelljs')
const path = require('path')
const fs = require('fs')
const mkdirp = require('mkdirp')
const child_process = require('child_process')
const os = require('os')

const config = require(`./${process.argv[2]}`)

config.packages.system.aur.push('pikaur')

nunjucks.configure({
	autoescape: false,
	throwOnUndefined: true
})

const exec = cmd => child_process.execSync(cmd, { stdio: 'inherit' })

let buildDirectory = undefined
const setBuildDirectory = () => {
	buildDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'generate-iso'))
	console.log(`Build directory created [${buildDirectory}]`)
}

const renderTpl = filePath => {
	mkdirp.sync(path.resolve(buildDirectory, path.dirname(filePath)))

	fs.writeFileSync(
		path.resolve(buildDirectory, filePath),
		nunjucks.render(
			path.resolve(__dirname, path.join('tpl', filePath)),
			config
		)
	)
}

try {
	setBuildDirectory()
	shelljs.cp('-R', path.resolve(__dirname, 'isofiles/'), path.join(buildDirectory, 'isofiles/'))
	renderTpl('build-iso.sh')
	renderTpl('isofiles/root/install.sh')
	renderTpl('isofiles/root/chroot-install.sh')
	renderTpl('Dockerfile')
	renderTpl('isofiles/etc/vconsole.conf')

	const buildName = `archlinux-isobuild-${Date.now()}`

	exec(`docker build --no-cache -t ${buildName} ${buildDirectory}`)
	exec(`docker run --privileged --rm -v ${path.resolve(__dirname, '../iso/')}:/archiso/out/ ${buildName} /bin/bash usr/sbin/build-iso.sh`)
	exec(`docker rmi ${buildName}`)
} catch (err) {
	console.error(err)
} finally {
	if (buildDirectory) {
		console.log(`Removing build directory [${buildDirectory}]`)
		shelljs.rm('-rf', buildDirectory)
	}
}
