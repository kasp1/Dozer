import { WebSocketServer } from 'ws'

export default {
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
          api.runner.log('The --api-port argument has been specified but was not followed by a valid integer. Ignoring.', apiPort)
        }
      } else {
        api.runner.log('The --api-port argument has been specified but was not followed by a port number. Ignoring.')
      }
    }

    api.runner.log('Starting API on', port)
    const wss = new WebSocketServer({ port: port })
    wss.on('connection', api.connected)
  },

  waitForFirstConnection () {
    api.runner.log('Waiting 10 seconds for a UI to connect...')

    api.firstUiConnectionTimeout = setTimeout(() => {
      api.runner.log('No UI has connected, starting the pipeline...')

      api.runner.start()
    }, 10000)
  },

  connected (ws) {
    api.clients.push(ws)
    clearTimeout(api.firstUiConnectionTimeout)

    ws.on('message', function message(data) {
      console.log('received: %s', data)
    });

    ws.send('something')

    api.runner.updateVars()
    api.runner.start()
  },

  sendToAll (body) {
    for (let client of clients) {
      client.send(JSON.stringify(body))
    }
  },

  sendTo (ws, body) {
    ws.send(JSON.stringify(body))
  },

  sendEnvironmentVariables () {
    let allVars = { ...api.runner.addedVars, ...api.runner.collectedEnvVars }

    api.sendToAll({
      envVars: allVars
    })
  },

  sendOutput (step, output) {
    output = output.toString()
    output = output.replace(/`/g, '\'')
    output = output.replace(/\\/g, '/')

    api.sendToAll({
      step: step,
      output: output
    })
  },

  sendStatus (step, status, totalTime) {
    let message = {
      step: step,
      status: status
    }

    if (totalTime) {
      message.totalTime = totalTime
    }

    api.sendToAll(message)
  },
}