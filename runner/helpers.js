const path = require('path')
const os = require('os')
const Axios = require('axios')
const fs = require('fs')

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
  }
}

module.exports = helpers