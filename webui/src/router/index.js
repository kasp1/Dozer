import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'main',
      component: require('@/screens/MainScreen.vue').default
    },
    {
      path: "/.*/g",
      redirect: '/'
    }
  ]
})

export default router
