<template>
  <div id="wrapper">
    <div id="side">
      <div id="steps" class="section">
        <a 
          class="step" 
          v-for="(title, step) in steps"
          :key="step"
          @click="selectedStep = step"
          :data-active="step == selectedStep ? true : false">
            <span :data-indicator="indicator(step)">{{ indicator(step) }}</span> {{ title }} <span v-if="times[step]">{{ times[step] }}</span>
        </a>
      </div>
      <div id="environment" class="section">
        <span 
          v-for="(value, variable) in vars"
          :key="variable"
          class="var"
          :title="value">
            <b>${&ZeroWidthSpace;{{ variable }}&ZeroWidthSpace;}</b> {{ value }}
        </span>
        <p>Only selected environment variables are displayed here.</p> 
      </div>
    </div>

    <pre id="output" class="terminal">{{ outputs[selectedStep] ? outputs[selectedStep] : 'Waiting for output of ' + steps[selectedStep] + '...' }}</pre>

    <span v-if="connectionStatus && !hasFinished" id="status">{{ connectionStatus }}</span>
  </div>
</template>

<script>
export default {
  data () {
    return {
      vars: {},
      steps: [],
      outputs: [],
      statuses: [],
      times: [],
      selectedStep: 0,
      connection: null,
      connectionStatus: 'Connecting...'
    }
  },
  computed: {
    output () {
      if (this.outputs[this.selectedStep]) {
        return this.outputs[this.selectedStep]
      }

      return 'Waiting for output...'
    },
    hasFinished () {
      if (this.statuses.length) {
        if ((this.statuses.at(-1) == 'success') || (this.statuses.at(-1) == 'failure')) {
          return true
        }
      }
      
      return false
    }
  },
  methods: {
    indicator (step) {
      if (this.statuses[step] !== undefined) {
        switch (this.statuses[step]) {
          case 'success': return '✔'
          case 'progress': return '➔'
          case 'failure': return '✘'
          default: return '●'
        }
      }

      return '●'
    },
    appendOutput (index, data) {
      this.outputs[index] = this.outputs[index] + data
      this.selectedStep = index
      this.$forceUpdate()

      window.setTimeout(() => {
        let el = document.getElementById('output')
        el.scrollTop = el.scrollHeight
      }, 250)
    },
    connect () {
      let host = window.location.hash.substring(1) || 'localhost:8220'

      this.connection = new WebSocket(`ws://${host}/`)

      this.connection.onmessage = (event) => {
        let data = JSON.parse(event.data)

        console.log(data)

        if (data.recap) {
          this.processRecap(data.recap)
        }

        if ((data.step !== undefined) && data.output) {
          this.appendOutput(data.step, data.output)
        }

        if ((data.step !== undefined) && data.status) {
          this.statuses[data.step] = data.status

          if (data.totalTime) {
            this.times[data.step] = data.totalTime
          }

          if (data.vars) {
            this.vars = data.vars
          }
        }
      }

      this.connection.onopen = () => {
        this.connectionStatus = ''
      }

      this.connection.onclose = () => {
        this.connectionStatus = 'Disconnected, refresh to reconnect.'
      }
    },
    processRecap (recap) {
      this.steps = []
      this.statuses = []
      this.outputs = []
      this.times = []

      for (let step of recap) {
        this.steps.push(step.title)
        this.statuses.push(step.status)
        this.outputs.push(step.output)

        if (step.totalTime) {
          this.times.push(step.totalTime)
        }

        if (step.startVars) {
          this.vars = step.startVars
        }

        if (step.endVars) {
          this.vars = step.endVars
        }

        this.selectedStep = step
      }
    }
  },
  created () {
    this.connect()
  }
}
</script>

<style>

  body, html {
    padding: 0;
    margin: 0;
    overflow-y: hidden;
    font-family: BlinkMacSystemFont, -apple-system, "Segoe UI", "Roboto", "Oxygen", "Ubuntu", "Cantarell", "Fira Sans", "Droid Sans", "Helvetica Neue", "Helvetica", "Arial", sans-serif;
  }

  pre {
    margin: 0;
  }

  #side {
    width: 200px;
    height: 100vh;
    box-sizing: border-box;
    background-color: #252526;
    overflow-x: hidden;
    overflow-y: auto;
    float: left;
  }

  .section {
    border-bottom: 1px solid #3e3e3f;
    padding: 5px 10px;
  }

  #output {
    width: calc(100vw - 200px);
    height: 100vh;
    box-sizing: border-box;
  }

  #environment {
    font-size: 11px;
    color: #666666;
  }

  .terminal {
    background-color: #1e1e1e;
    color: #bbbbbb;
    padding: 5px 10px;
    overflow: auto;
    font-size: 11px;
    white-space: pre-wrap;
    word-wrap: break-word;
    box-sizing: border-box;
  }

  #steps {
    margin-top: 10px;
    padding-bottom: 10px;
  }

  .step {
    display: block;
    margin-bottom: 6px;
    font-size: 14px;
    color: #bbbbbb;
    cursor: pointer;
  }

  .step:hover {
    color: #ffffff;
  }

  .step[data-active="true"] {
    color: #ffffff;
  }

  .step span[data-indicator="✔"] { color: greenyellow; }
  .step span[data-indicator="➔"] { color: lightskyblue; }
  .step span[data-indicator="✘"] { color: orangered; }
  .step span[data-indicator="●"] { color: white; }

  .step span:nth-child(2) {
    color: #bbbbbb;
    background-color: #1e1e1e;
    font-size: 11px;
    border-radius: 3px;
    padding: 2px 4px;
  }

  .var {
    color: #bbbbbb;
    display: block;
    margin-bottom: 6px;
  }

  ::-webkit-scrollbar {
    width: 10px;
    height: 10px;
  }
  ::-webkit-scrollbar-button {
    width: 0px;
    height: 0px;
  }
  ::-webkit-scrollbar-thumb {
    background: #3e3e3f;
    border: 1px none #ffffff;
    border-radius: 0px;
  }
  ::-webkit-scrollbar-thumb:hover {
    background: #5e5e5f;
  }
  ::-webkit-scrollbar-thumb:active {
    background: #5e5e5f;
  }
  ::-webkit-scrollbar-track {
    background: #2e2e2f;
    border: 0px none #ffffff;
    border-radius: 0px;
  }
  ::-webkit-scrollbar-track:hover {
    background: #2e2e2f;
  }
  ::-webkit-scrollbar-track:active {
    background: #333333;
  }
  ::-webkit-scrollbar-corner {
    background: transparent;
  }

  #status {
    position: fixed;
    top: 10px;
    right: 10px;
    background: #3e3e3f;
    padding: 5px 10px;
    border-radius: 5px;
    color: white;
    font-size: 12px;
  }
</style>
