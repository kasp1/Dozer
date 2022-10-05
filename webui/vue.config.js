const { defineConfig } = require('@vue/cli-service')
module.exports = defineConfig({
  transpileDependencies: true,
  outputDir: require('path').resolve(__dirname, "../dist/webui")
})
