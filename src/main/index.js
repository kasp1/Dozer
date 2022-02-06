'use strict'

import { app, BrowserWindow } from 'electron'
import fs from 'fs'
import path from 'path'
import YAML from 'yaml'
import { exec } from 'child_process'
import Axios from 'axios'

/**
 * Set `__static` path to static files in production
 * https://simulatedgreg.gitbooks.io/electron-vue/content/en/using-static-assets.html
 */
if (process.env.NODE_ENV !== 'development') {
  global.__static = require('path').join(__dirname, '/static').replace(/\\/g, '\\\\')
}

let runner = {
  gui: false,
  window: null,
  url: '',
  collectedEnvVars: {},
  lastEnv: [],
  yaml: null,
  failure: false,
  electronRoot: '',
  PATH: [],
  tmp: '',
  startTime: null,
  totalTimes: [],
  addedVars: {},
  cmdRoot: false,

  init () {
    runner.url = process.env.NODE_ENV === 'development'
      ? `http://localhost:9080`
      : `file://${__dirname}/index.html`

    runner.gui = process.argv.includes('--gui')

    if (process.argv.includes('--root')) {
      let rootDirArgPos = process.argv.indexOf('--root')
      let rootDir = process.argv[rootDirArgPos + 1]

      if (rootDir) {
        if (fs.existsSync(rootDir)) {
          runner.cmdRoot = rootDir
          runner.log('Changing working directory to', runner.cmdRoot)
          process.chdir(runner.cmdRoot)
        } else {
          runner.log('The --root argument has been specified but the path does not seem to exist. Ignoring.', rootDir)
        }
      } else {
        runner.log('The --root argument has been specified but was not followed by a path. Ignoring.')
      }
    }

    runner.electronRoot = path.resolve(__dirname)
    runner.PATH = process.env.path.replace(/\\/g, '/').split(';')
    runner.tmp = app.getPath('temp')

    app.on('ready', runner.createWindow)

    app.on('window-all-closed', () => {
      if (process.platform !== 'darwin') {
        app.quit()
      }
    })

    app.on('activate', () => {
      if (runner.window === null) {
        runner.createWindow()
      }
    })

    if (!runner.gui) {
      runner.start()
    }
  },

  createWindow () {
    if (!runner.gui) {
      return
    }

    runner.log('Loading GUI...')

    runner.window = new BrowserWindow({
      height: 1000,
      useContentSize: true,
      width: 1000,
      webPreferences: {
        nodeIntegration: true,
        nodeIntegrationInWorker: true
      },
      frame: false
    })

    runner.window.setMenu(null)

    runner.window.loadURL(runner.url)

    runner.window.on('closed', () => {
      runner.window = null
    })

    runner.window.webContents.on('did-finish-load', () => {
      runner.log('GUI loaded.')
      runner.updateVars()
      runner.start()
    })
  },

  collectEnvVars () {
    let importantVars = [ 'OS', 'TMP', 'HOME', 'JAVA_HOME', 'PROCESSOR_ARCHITECTURE' ]

    for (let v in process.env) {
      if (importantVars.includes(v)) {
        runner.collectedEnvVars[v] = process.env[v].replace(/\\/g, '/')
      }
    }
  },

  vueUpdateValue (target, value) {
    if (runner.gui) {
      runner.window.webContents.executeJavaScript('window.vueMain.' + target + ' = JSON.parse(\'' + JSON.stringify(value) + '\')').catch(() => {})
      runner.window.webContents.executeJavaScript('window.vueMain.$forceUpdate()').catch(() => {})
    }
  },

  vueAttachValueToArray (target, value) {
    if (runner.gui) {
      value = value.replace('`', '\'')

      runner.window.webContents.executeJavaScript('window.vueMain.' + target + '.push(`' + value + '`)').catch(() => {})
    }
  },

  vueAppendOutput (index, value) {
    if (runner.gui) {
      value = value.toString()
      value = value.replace(/`/g, '\'')
      value = value.replace(/\\/g, '/')

      try {
        runner.window.webContents.executeJavaScript('window.vueMain.appendOutput(' + index + ', `' + value + '`)')
      } catch (e) {}
    }
  },

  updateVars () {
    runner.collectEnvVars()
    let allVars = { ...runner.addedVars, ...runner.collectedEnvVars }

    console.log(allVars)

    runner.vueUpdateValue('vars', allVars, true)
  },

  start () {
    runner.parseYaml()

    if (runner.yaml.runtimeDirectory) {
      if (!runner.cmdRoot) {
        runner.log('Changing working directory to', runner.yaml.runtimeDirectory)
        process.chdir(runner.yaml.runtimeDirectory)
      } else {
        runner.log('Root directory has been specified in the configuration YAML, but it has been overriden by the --root argument.')
      }
    }

    runner.log('Running CI steps')

    runner.exec(0, runner.yaml.steps[0])
  },

  async exec (index, step) {
    runner.log('Initiating step', step.displayName)

    runner.vueAttachValueToArray('statuses', 'progress')

    let options = {
      env: { ...process.env, ...runner.addedVars }
    }

    // change working directory if set
    if (step.workingDirectory) {
      if (fs.existsSync(step.workingDirectory)) {
        options.cwd = step.workingDirectory
      } else {
        runner.log('ERROR: The working directory specified for step', step.displayName, 'does not exist.')
      }
    }

    // download gist if necessary
    if (step.code) {
      let fileName = step.code.split('/')
      fileName = fileName[fileName.length - 1]

      let filePath = path.join(runner.tmp, fileName)

      if (fs.existsSync(filePath)) {
        runner.log('Downloading code...')

        try {
          let response = await Axios.get(step.code)

          if (response.status === 200) {
            fs.writeFileSync(filePath, response.data)
          } else {
            runner.log(`ERROR: Couldn't download code (HTTP error ${response.status})`)
          }
        } catch (e) {
          runner.log(e)
        }
      }
    }

    let command = step.command

    // replace variables in the command with values
    for (let v in process.env) {
      command = command.replace(new RegExp('$' + v, 'g'), process.env[v])
    }

    for (let v in runner.addedVars) {
      command = command.replace(new RegExp('$' + v, 'g'), runner.addedVars[v])
    }

    // run the exec
    runner.log('Executing step', step.displayName, ':', step.command)

    runner.startTime = Date.now()

    let proc = exec(`${step.command}`, { windowsVerbatimArguments: true, ...options })

    proc.on('error', (err) => {
      console.log(err)
      runner.guiLog(index, err)
    })

    proc.stdout.setEncoding('utf8')
    proc.stderr.setEncoding('utf8')

    proc.stdout.on('data', (data) => {
      let matches = data.toString().match(/##[a-zA-Z0-9_]+=.+#/gm)

      // does this contain a variable definition?
      if (matches) {
        console.log('Found variable definition', matches)

        let str
        for (let match of matches) {
          str = match.replace(/^##/, '').replace(/#$/, '')
          str = str.split('=')

          runner.log('Setting env var', str[0], 'to', str[1].trim())
          runner.addedVars[str[0]] = str[1].trim()
        }
      } else {
        console.log(data.toString())
      }

      runner.guiLog(index, data.toString())
    })

    proc.stderr.on('data', (data) => {
      let str = data.toString()
      console.log(str)
      runner.guiLog(index, str.toString())
    })

    proc.on('close', (code) => {
      let totalTime = Math.abs(new Date() - runner.startTime)
      runner.totalTimes.push(totalTime)
      totalTime = runner.formatTime(totalTime)

      runner.updateVars()

      if (code === 0) {
        runner.log('Sucessfully executed:', step.displayName, 'took', totalTime)

        runner.vueUpdateValue('statuses[' + index + ']', 'success')
        runner.vueUpdateValue('times[' + index + ']', totalTime)

        if (runner.yaml.steps[index + 1]) {
          runner.exec(index + 1, runner.yaml.steps[index + 1])
        } else {
          runner.finish()
        }
      } else if (step.skippable === true) {
        runner.failure = true
        runner.log('Failure (exit code ' + code + ') during step:', step.displayName, 'took', totalTime)

        runner.vueUpdateValue('statuses[' + index + ']', 'failure')
        runner.vueUpdateValue('times[' + index + ']', totalTime)

        if (runner.yaml.steps[index + 1]) {
          runner.exec(index + 1, runner.yaml.steps[index + 1])
        } else {
          runner.finish()
        }
      } else {
        runner.failure = true
        runner.log('Failure (exit code ' + code + ') during step:', step.displayName, 'took', totalTime)

        runner.vueUpdateValue('statuses[' + index + ']', 'failure')
        runner.vueUpdateValue('times[' + index + ']', totalTime)

        runner.finish()
      }
    })
  },

  finish () {
    runner.log('Finishing CI steps')

    if (!runner.gui) {
      process.exit()
    }
  },

  parseYaml () {
    let yamlFile

    for (let arg in process.argv) {
      if (process.argv[arg].includes('.yaml') || process.argv[arg].includes('.yml')) {
        yamlFile = process.argv[arg]
      }
    }

    if (!fs.existsSync(yamlFile)) {
      runner.log('ERROR: The specified YAML file does not exist.')
      process.exit(1)
    }

    runner.yaml = YAML.parse(fs.readFileSync(yamlFile, 'utf8'))

    if (runner.gui) {
      let guiSteps = []
      let guiOutputs = []

      for (let step in runner.yaml.steps) {
        guiSteps.push(runner.yaml.steps[step].displayName)
        guiOutputs.push('')
      }

      runner.vueUpdateValue('steps', guiSteps)
      runner.vueUpdateValue('outputs', guiOutputs)
    }
  },

  log (...args) {
    args.sort((a, b) => { return a - b })

    let stamp = []

    let now = new Date()

    stamp.push(
      runner.prependZero(now.getHours()) + ':' +
      runner.prependZero(now.getMinutes()) + ':' +
      runner.prependZero(now.getSeconds()) + '.' +
      runner.prependZero(now.getMilliseconds())
    )

    stamp.push(
      now.getFullYear() +
      '-' +
      runner.prependZero(now.getMonth() + 1) +
      '-' +
      runner.prependZero(now.getDate())
    )

    args.unshift('[ ' + stamp.join(' ') + ' ]')

    // send to console
    console.log.apply(console, args)
  },

  prependZero (num) {
    return num.toString().length === 1 ? '0' + num : num.toString()
  },

  guiLog (step, data) {
    if (runner.gui) {
      runner.vueAppendOutput(step, data)
    }
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
  }
}

runner.init()
