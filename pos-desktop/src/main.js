import { createApp } from 'vue'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import Aura from '@primevue/themes/aura'
import ToastService from 'primevue/toastservice'
import DialogService from 'primevue/dialogservice'
import ConfirmationService from 'primevue/confirmationservice'
import Tooltip from 'primevue/tooltip'

import App from './App.vue'
import router from './router/index.js'
import './assets/style.css'

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(PrimeVue, {
  theme: {
    preset: Aura,
    options: {
      darkModeSelector: 'body',
      cssLayer: false
    }
  }
})
app.use(ToastService)
app.use(DialogService)
app.use(ConfirmationService)
app.directive('tooltip', Tooltip)

app.mount('#app')
