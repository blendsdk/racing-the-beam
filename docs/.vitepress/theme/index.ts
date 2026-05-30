import DefaultTheme from 'vitepress/theme'
import './custom.css'
import RomPlayer from './components/RomPlayer.vue'

export default {
  ...DefaultTheme,
  enhanceApp({ app }) {
    app.component('RomPlayer', RomPlayer)
  }
}
