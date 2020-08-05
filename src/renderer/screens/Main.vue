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
            <span :data-indicator="indicator(step)">{{ indicator(step) }}</span> {{ title }}
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
  </div>
</template>

<script>
  export default {
    name: 'main',
    data () {
      return {
        vars: {},
        steps: [],
        outputs: [],
        statuses: [],
        selectedStep: 0
      }
    },
    computed: {
      output () {
        if (this.outputs[this.selectedStep]) {
          return this.outputs[this.selectedStep]
        }

        return 'Waiting for output of ' + this.steps[this.selectedStep] + '...'
      }
    },
    methods: {
      open (link) {
        this.$electron.shell.openExternal(link)
      },
      indicator (step) {
        if (this.statuses[step] !== undefined) {
          switch (this.statuses[step]) {
            case 'success': return '✔'
            case 'progress': return '➔'
            case 'failure': return '✘'
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
      }
    },
    created () {
      window.vueMain = this
    }
  }
</script>

<style>

  body, html {
    padding: 0;
    margin: 0;
    overflow-y: hidden;
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
    padding-bottom: 16px;
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
</style>
