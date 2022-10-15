const fs = require('fs')
const YAML = require('yaml')
const { exec } = require('child_process')
const open = require('open')

const h = require('./helpers.js')
const api = require('./api.js')
const helpers = require('./helpers.js')

let runner = {
  yaml: null,
  failure: false,
  startTime: null,
  totalTimes: [],
  addedVars: {},
  cmdRoot: false,
  provideApi: true,
  running: false,

  async init () {
    api.runner = runner
    runner.parseYaml()

    // use a pipeline-level working directory if specified
    if (process.argv.includes('--root')) {
      let rootDirArgPos = process.argv.indexOf('--root')
      let rootDir = process.argv[rootDirArgPos + 1]

      if (rootDir) {
        if (fs.existsSync(rootDir)) {
          runner.cmdRoot = rootDir
          h.log('Changing working directory to', runner.cmdRoot)
          process.chdir(runner.cmdRoot)
        } else {
          h.log('The --root argument has been specified but the path does not seem to exist. Ignoring.', rootDir)
        }
      } else {
        h.log('The --root argument has been specified but was not followed by a path. Ignoring.')
      }
    }

    runner.provideApi = !process.argv.includes('--no-api')
    
    if (runner.provideApi) {
      api.init()
    } else {
      h.log('The --no-api argument has been specified, UI API will not start.')
      return
    }

    // if a UI is desired, wait for it to connect to the API before starting, otherwise start right away
    if (process.argv.includes('--webui') || process.argv.includes('--gui')) {
      api.waitForFirstConnection()
    } else {
      h.log('Starting the pipeline...')
      runner.start()
    }

    // starts the webserver and serves the Web UI
    if (process.argv.includes('--webui')) {
      let webuiArgPos = process.argv.indexOf('--webui')
      let webuiUrl = process.argv[webuiArgPos + 1]

      if (webuiUrl) {
        if (!webuiUrl.startsWith('--')) {
          open(webuiUrl)
        } else {
          await h.serveWebUi()
        }
      } else {
        await h.serveWebUi()
      }
    }

    // will try to start the Native UI by command
    if (process.argv.includes('--gui')) {
      let guiArgPos = process.argv.indexOf('--gui')
      let guiCommand = process.argv[guiArgPos + 1]

      if (guiCommand) {
        if (!guiCommand.startsWith('--')) {
          exec(guiCommand)
        } else {
          exec('dozerui')
        }
      } else {
        exec('dozerui')
      }
    }
  },

  start () {
    runner.running = true

    if (runner.yaml.runtimeDirectory) {
      if (!runner.cmdRoot) {
        h.log('Changing working directory to', runner.yaml.runtimeDirectory)
        process.chdir(runner.yaml.runtimeDirectory)
      } else {
        h.log('Root directory has been specified in the configuration YAML, but it has been overriden by the --root argument.')
      }
    }

    h.log('Running CI steps...')

    runner.exec(0, runner.yaml.steps[0])
  },

  async exec (index, step) {
    h.log('Initiating step', h.getTitle(step))

    if (runner.provideApi) {
      // wait 1 second before sending another step status over API
      await new Promise(r => setTimeout(r, 1000))
      api.sendStatus(index, 'progress')
    }

    let options = {
      env: { ...process.env, ...runner.addedVars }
    }

    // change working directory if set
    if (step.workingDirectory) {
      if (fs.existsSync(step.workingDirectory)) {
        options.cwd = step.workingDirectory
      } else {
        h.log('ERROR: The working directory specified for step', h.getTitle(step), 'does not exist.')
      }
    }

    // download if necessary
    if (step.code) {
      await h.download(step.code)
    }

    let command = step.command

    // replace variables in the command with values
    for (let v in process.env) {
      command = command.replace(new RegExp('\\${' + v + '}', 'gm'), process.env[v])
    }

    for (let v in runner.addedVars) {
      command = command.replace(new RegExp('\\${' + v + '}', 'gm'), runner.addedVars[v])
    }

    // if the command contains a "node" (NodeJS) call to a script, by default the script would be
    // executed by the NodeJS version embedded with Dozer, which doesn't support ES6 "import",
    // it does support only CommonJS "require". This can be worked-around by specifying direct
    // path to the system's NodeJS binary in the command, which is done automatically by
    // the following line. https://github.com/vercel/pkg/issues/1291
    //
    // Note: this has only effect in shipped builds where NodeJS is embedded by `pkg`
    command = helpers.replaceNodeInCommand(command)

    // run the exec
    h.log('Executing step', h.getTitle(step) + ':', command)

    runner.startTime = Date.now()

    let proc = exec(`${command}`, { windowsVerbatimArguments: true, ...options })

    proc.stdout.setEncoding('utf8')
    proc.stderr.setEncoding('utf8')
    proc.stdout.on('data', (data) => runner.onStepOutput(index, data))
    proc.stderr.on('data', (data) => runner.onStepOutput(index, data))
    proc.on('error', (err) => runner.onStepOutput(index, err))
    proc.on('close', (code) => runner.onStepFinished(index, step, code))
  },

  onStepOutput (step, data) {
    let matches = data.toString().match(/##[a-zA-Z0-9_]+=.+#/gm)

    // does this contain a variable definition?
    if (matches) {
      console.log('Found variable definition', matches)

      let str
      for (let match of matches) {
        str = match.replace(/^##/, '').replace(/#$/, '')
        str = str.split('=')

        h.log('Setting env var', str[0], 'to', str[1].trim())
        runner.addedVars[str[0]] = str[1].trim()
      }
    } else {
      console.log(data.toString().trim())
    
      if (runner.provideApi) {
        api.sendOutput(step, data.toString())
      }
    }
  },

  async onStepFinished (stepIndex, step, exitCode) {
    let totalTime = Math.abs(new Date() - runner.startTime)
    runner.totalTimes.push(totalTime)
    totalTime = h.formatTime(totalTime)

    // finished successfully
    if (exitCode === 0) {
      h.log('Sucessfully executed:', h.getTitle(step), 'took', totalTime)

      if (runner.provideApi) {
        api.sendStatus(stepIndex, 'success', totalTime)
      }

      if (runner.yaml.steps[stepIndex + 1]) {
        runner.exec(stepIndex + 1, runner.yaml.steps[stepIndex + 1])
      } else {
        runner.finish()
      }

    // failed but was skippable
    } else if (step.skippable === true) {
      runner.failure = true
      h.log('Failure (exit code ' + exitCode + ') during step:', h.getTitle(step), 'took', totalTime)

      if (runner.provideApi) {
        api.sendStatus(stepIndex, 'failure', totalTime)
      }

      if (runner.yaml.steps[stepIndex + 1]) {
        runner.exec(stepIndex + 1, runner.yaml.steps[stepIndex + 1])
      } else {
        runner.finish()
      }

    // failed
    } else {
      runner.failure = true
      h.log('Failure (exit code ' + exitCode + ') during step:', h.getTitle(step), 'took', totalTime)

      if (runner.provideApi) {
        api.sendStatus(stepIndex, 'failure', totalTime)
      }

      runner.finish()
    }
  },

  finish () {
    h.log('Finishing CI steps')

    if (!runner.ui) {
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
      h.log('ERROR: The specified YAML file does not exist.')
      process.exit(1)
    }

    runner.yaml = YAML.parse(fs.readFileSync(yamlFile, 'utf8'))

    if (runner.provideApi) {
      for (let step in runner.yaml.steps) {
        api.recap[step] = {
          title: h.getTitle(runner.yaml.steps[step]),
          output: '',
          status: 'initial'
        }
      }
    }
  }
}

runner.init()
