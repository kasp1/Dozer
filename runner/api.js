const { WebSocketServer } = require('ws')
const h = require('./helpers.js')

let api = {
  runner: null,
  firstUiConnectionTimeout: null,
  clients: [],
  sensitiveWords: ['secret', 'password', 'pwd', 'passwd', 'token'],

  // this variable holds all steps and their statuses and outputs for the purpose
  // of any UI client that connects at a later stage of execution
  recap: [],

  init () {
    h.log('Starting API on', h.getApiPort())
    const wss = new WebSocketServer({ port: h.getApiPort() })
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
    vars = h.hideValuesOfSensitiveVars(vars, api.sensitiveWords)

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