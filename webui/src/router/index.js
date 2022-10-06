import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'main',
      component: require('@/screens/Main.vue').default
    },
    {
      path: '*',
      redirect: '/'
    }
  ]
})

export default router
