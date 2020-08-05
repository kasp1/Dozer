import Vue from 'vue'
import Buefy from 'buefy'
import 'buefy/dist/buefy.css'
import { Titlebar, Color } from 'custom-electron-titlebar'

import App from './App'
import router from './router'

Vue.use(Buefy)

if (!process.env.IS_WEB) Vue.use(require('vue-electron'))
Vue.config.productionTip = false

/* eslint-disable no-new */
let titleBar = new Titlebar({
  backgroundColor: Color.fromHex('#3c3c3c'),
  menu: null,
  titleHorizontalAlignment: 'left',
  overflow: 'hidden'
})

titleBar.updateIcon('./src/renderer/assets/256x256.png')

/* eslint-disable no-new */
new Vue({
  components: { App },
  router,
  template: '<App/>'
}).$mount('#app')
