<template>
  <div id="wrapper">
    <div id="side" class="is-info is-light">
      <div id="steps">
        <a 
          class="step" 
          v-for="(title, step) in steps"
          :key="step"
          @click="selectedStep = step"
          :data-active="step == selectedStep ? true : false">
            <span :data-indicator="indicator(step)">{{ indicator(step) }}</span> {{ title }}
        </a>
      </div>
      <div id="environment">
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
    background-color: #101010;
    padding: 5px 10px;
    overflow-x: hidden;
    overflow-y: auto;
    float: left;
  }

  #output {
    width: calc(100vw - 200px);
    height: 100vh;
    box-sizing: border-box;
  }

  #environment {
    margin-top: 40px;
    font-size: 11px;
    color: #666666;
  }

  .terminal {
    background-color: black;
    color: white;
    padding: 5px 10px;
    overflow: auto;
    font-size: 11px;
    white-space: pre-wrap;
    word-wrap: break-word;
  }

  #steps {
    margin-top: 10px;
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
    display: block;
    margin-bottom: 6px;
  }
</style>
