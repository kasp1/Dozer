const path = require('path')
const os = require('os')
const Axios = require('axios').default
const fs = require('fs')
const open = require('open')
const express = require('express')
const execSync = require('child_process').execSync

let helpers = {
  log (...args) {
    args.sort((a, b) => { return a - b })

    let stamp = []

    let now = new Date()

    stamp.push(
      helpers.prependZero(now.getHours()) + ':' +
      helpers.prependZero(now.getMinutes()) + ':' +
      helpers.prependZero(now.getSeconds()) + '.' +
      helpers.prependZero(now.getMilliseconds())
    )

    stamp.push(
      now.getFullYear() +
      '-' +
      helpers.prependZero(now.getMonth() + 1) +
      '-' +
      helpers.prependZero(now.getDate())
    )

    args.unshift('[ ' + stamp.join(' ') + ' ]')

    // send to console
    console.log.apply(console, args)
  },

  prependZero (num) {
    return num.toString().length === 1 ? '0' + num : num.toString()
  },

  formatTime (millis) {
    let second = 1000
    let minute = second * 60
    let hour = minute * 60

    if (millis > hour) {
      return Math.floor(millis / hour) + 'h ' + Math.round((millis % hour) / minute) + 'm'
    }

    if (millis > minute) {
      return Math.floor(millis / minute) + 'm ' + Math.round((millis % minute) / second) + 's'
    }

    return (millis / 1000) + 's'
  },

  async download (url) {
    let fileName = url.split('/')
    fileName = fileName[fileName.length - 1]

    let filePath = path.join(os.tmpdir(), fileName)

    helpers.log('Downloading code...')

    try {
      let response = await Axios.get(url)

      if (response.status === 200) {
        helpers.log('Saving code to:', filePath)
        fs.writeFileSync(filePath, response.data)
      } else {
        helpers.log(`ERROR: Couldn't download code (HTTP error ${response.status})`)
      }
    } catch (e) {
      helpers.log(e)
    }
  },

  getTitle (step) {
    return step.title ? step.title : step.displayName
  },

  collectEnvVars () {
    let importantVars = [ 'OS', 'TMP', 'HOME', 'JAVA_HOME', 'PROCESSOR_ARCHITECTURE' ]
    let collectedVars = {}

    for (let v in process.env) {
      if (importantVars.includes(v)) {
        collectedVars[v] = process.env[v].replace(/\\/g, '/')
      }
    }

    return collectedVars
  },

  getPort (arg, port) {
    if (process.argv.includes(arg)) {
      let portArgPos = process.argv.indexOf(arg)
      let portArgValue = process.argv[portArgPos + 1]

      if (portArgValue) {
        let newPort = parseInt(portArgValue)

        if (newPort.isInteger()) {
          port = newPort
        } else {
          h.log(`The ${arg} argument has been specified but was not followed by a valid integer. Ignoring.`, portArgValue)
        }
      } else {
        h.log(`The ${arg} argument has been specified but was not followed by a port number. Ignoring.`)
      }
    }

    return port
  },

  getApiPort () {
    return helpers.getPort('--api-port', 8220)
  },

  getWebuiPort () {
    return helpers.getPort('--webui-port', 8221)
  },

  async serveWebUi () {
    let port = helpers.getWebuiPort()
    let webUiRoot = path.join(__dirname, 'webui')
    let server = express()

    if (process.env['DOZER_DEV_WEBUI_DIR']) {
      webUiRoot = process.env['DOZER_DEV_WEBUI_DIR']
    } else {
      let dozerRoot = helpers.findBinaryPath('dozer', null)

      console.log('dozerRoot', dozerRoot)

      if (dozerRoot) {
        webUiRoot = path.join(path.dirname(dozerRoot), 'webui')
      }
    }

    server.use(express.static(webUiRoot))
    server.listen(port)
    helpers.log('Serving WebUI on', port, 'from', webUiRoot)

    open(`http://localhost:${port}/#localhost:${helpers.getApiPort()}`)
  },

  node: '',
  findNodeExecutable() {
    helpers.node = helpers.findBinaryPath('node', 'node')

    if (helpers.node != 'node') {
      helpers.node = `"${helpers.node}"`
    }
  },

  replaceNodeInCommand(command) {
    if (helpers.node == '') {
      helpers.findNodeExecutable()
    }

    // replaces "node" at the beginning of the command
    command = command.replace(/^node/gm, helpers.node)
    // replaces "node" after each & or &&
    command = command.replace(/(?<=&\W*)node/gm, helpers.node)

    return command
  },

  findBinaryPath(command, failSafePath) {
    let found = ''

    switch (process.platform) {
      case 'linux': found = execSync('whereis ' + command, { econding: 'utf8' }).toString().trim(); break
      case 'win32': found = execSync('where ' + command, { econding: 'utf8' }).toString().trim(); break
      case 'darwin': found = execSync('which ' + command, { econding: 'utf8' }).toString().trim(); break
    }

    console.log('found', found)

    if (fs.existsSync(found)) {
      return found
    }

    return failSafePath
  },

  hideValuesOfSensitiveVars(vars, sensitive) {
    for (let key in vars) {
      if (helpers.containsSensitiveWord(key, sensitive)) {
        vars[key] = vars[key].replace(/./gm, '*')
      }
    }
    console.log(vars)

    return vars
  },

  containsSensitiveWord(string, sensitive) {
    return sensitive.some((word) => {
      const regex = new RegExp(word, 'gim')
      return regex.test(string)
    })
  }
}

module.exports = helpers