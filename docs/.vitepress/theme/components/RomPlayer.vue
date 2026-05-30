<script setup lang="ts">
import { ref, computed, onBeforeUnmount, nextTick } from 'vue'

const props = withDefaults(defineProps<{
  rom: string          // site-relative path, e.g. /roms/.../lesson01.bin
  title?: string
}>(), { title: 'Atari 2600 ROM' })

const base = import.meta.env.BASE_URL          // e.g. /racing-the-beam/
const open = ref(false)
const closeBtn = ref<HTMLButtonElement | null>(null)

function join(b: string, p: string) {
  return (b.endsWith('/') ? b.slice(0, -1) : b) + (p.startsWith('/') ? p : '/' + p)
}

const romUrl = computed(() => join(base, props.rom))
const playerSrc = computed(
  () => join(base, '/javatari/player.html') + '?cart=' + encodeURIComponent(romUrl.value)
)

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') close()
}

function openModal() {
  open.value = true
  if (typeof document !== 'undefined') {
    document.body.style.overflow = 'hidden'
    document.addEventListener('keydown', onKeydown)
  }
  nextTick(() => closeBtn.value?.focus())
}

function close() {
  open.value = false
  if (typeof document !== 'undefined') {
    document.body.style.overflow = ''
    document.removeEventListener('keydown', onKeydown)
  }
}

onBeforeUnmount(() => {
  if (typeof document !== 'undefined') {
    document.body.style.overflow = ''
    document.removeEventListener('keydown', onKeydown)
  }
})
</script>

<template>
  <div class="rom-player">
    <button class="rom-player__play" @click="openModal">
      ▶ Play "{{ title }}" in browser
    </button>
    <a class="rom-player__dl" :href="romUrl" download>⬇ Download ROM (.bin)</a>

    <Teleport to="body">
      <div
        v-if="open"
        class="rom-modal__backdrop"
        @click.self="close"
      >
        <div
          class="rom-modal__dialog"
          role="dialog"
          aria-modal="true"
          :aria-label="title"
        >
          <header class="rom-modal__bar">
            <span class="rom-modal__title">{{ title }}</span>
            <button
              ref="closeBtn"
              class="rom-modal__close"
              aria-label="Close emulator"
              @click="close"
            >✕</button>
          </header>
          <div class="rom-modal__frame">
            <iframe
              :src="playerSrc"
              :title="title"
              allow="autoplay; fullscreen; gamepad"
            ></iframe>
          </div>
          <footer class="rom-modal__meta">
            <a class="rom-player__dl" :href="romUrl" download>⬇ Download ROM (.bin)</a>
            <span class="rom-modal__hint">Arrow keys = joystick · Space = fire · (click the screen first)</span>
          </footer>
        </div>
      </div>
    </Teleport>
  </div>
</template>
