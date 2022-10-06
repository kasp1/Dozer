const { WebSocketServer } = require('ws')
const h = require('./helpers.js')

let api = {
  runner: null,
  firstUiConnectionTimeout: null,
  clients: [],

  // this variable holds all steps and their statuses and outputs for the purpose
  // of any UI client that connects at a later stage of execution
  recap: [],

  init () {
    let port = 8220

    if (process.argv.includes('--api-port')) {
      let apiPortArgPos = process.argv.indexOf('--api-port')
      let apiPort = process.argv[apiPortArgPos + 1]

      if (apiPort) {
        let newPort = parseInt(apiPort)

        if (newPort.isInteger()) {
          port = newPort
        } else {
          h.log('The --api-port argument has been specified but was not followed by a valid integer. Ignoring.', apiPort)
        }
      } else {
        h.log('The --api-port argument has been specified but was not followed by a port number. Ignoring.')
      }
    }

    h.log('Starting API on', port)
    const wss = new WebSocketServer({ port: port })
    wss.on('connection', api.connected)
  },

  waitForFirstConnection () {
    h.log('Waiting 10 seconds for a UI to connect...')

    api.firstUiConnectionTimeout = setTimeout(() => {
      h.log('No UI has connected, starting the pipeline...')

      api.runner.start()
    }, 10000)
  },

  connected (ws) {
    api.clients.push(ws)
    clearTimeout(api.firstUiConnectionTimeout)

    api.sendRecap(ws)

    if (!api.runner.running) {
      api.runner.start()
    }
  },

  sendToAll (body) {
    for (let client of api.clients) {
      client.send(JSON.stringify(body))
    }
  },

  sendTo (ws, body) {
    ws.send(JSON.stringify(body))
  },

  sendRecap (ws) {
    api.sendTo(ws, { recap: api.recap })
  },

  sendOutput (step, output) {
    output = output.toString()
    output = output.replace(/`/g, '\'')
    output = output.replace(/\\/g, '/')

    api.recap[step].output += output

    api.sendToAll({
      step: step,
      output: output
    })
  },

  sendStatus (step, status, totalTime) {
    let vars = { ...api.runner.addedVars, ...h.collectEnvVars() }

    api.recap[step].status = status

    if (status == 'progress') {
      api.recap[step].startVars = vars
    }

    if ((status == 'failure') || (status == 'success')) {
      api.recap[step].endVars = vars
    }

    let message = {
      step: step,
      status: status,
      vars: vars
    }

    if (totalTime) {
      api.recap[step].totalTime = totalTime
      message.totalTime = totalTime
    }

    api.sendToAll(message)
  },
}

module.exports = api