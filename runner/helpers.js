const path = require('path')
const os = require('os')
const Axios = require('axios')
const fs = require('fs')
const open = require('open')
const express = require('express')

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

    let server = express()

    if (process.env['DOZER_DEV_WEBUI_DIR']) {
      server.use(express.static(process.env['DOZER_DEV_WEBUI_DIR']))

      helpers.log('Serving WebUI from', process.env['DOZER_DEV_WEBUI_DIR'])
    } else {
      server.use(express.static(path.join(__dirname, 'webui')))
    }
    
    server.listen(port)

    helpers.log('Serving WebUI on', port)

    open(`http://localhost:${port}/#localhost:${helpers.getApiPort()}`)
  }
}

module.exports = helpers