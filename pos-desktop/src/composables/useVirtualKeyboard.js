import { ref, shallowRef } from 'vue'

const visible = ref(false)
const targetEl = shallowRef(null)
const numpadOnly = ref(false)

export function useVirtualKeyboard() {
  function show(el, options = {}) {
    targetEl.value = el
    numpadOnly.value = options.numpadOnly ?? false
    visible.value = true
  }

  function hide() {
    visible.value = false
    targetEl.value = null
  }

  function pressKey(char) {
    const el = targetEl.value
    if (!el) return
    const s = el.selectionStart ?? el.value.length
    const e = el.selectionEnd ?? el.value.length
    el.value = el.value.slice(0, s) + char + el.value.slice(e)
    el.selectionStart = el.selectionEnd = s + char.length
    el.dispatchEvent(new Event('input', { bubbles: true }))
  }

  function pressBackspace() {
    const el = targetEl.value
    if (!el) return
    const s = el.selectionStart ?? el.value.length
    const e = el.selectionEnd ?? el.value.length
    if (s !== e) {
      el.value = el.value.slice(0, s) + el.value.slice(e)
      el.selectionStart = el.selectionEnd = s
    } else if (s > 0) {
      el.value = el.value.slice(0, s - 1) + el.value.slice(s)
      el.selectionStart = el.selectionEnd = s - 1
    }
    el.dispatchEvent(new Event('input', { bubbles: true }))
  }

  return { visible, targetEl, numpadOnly, show, hide, pressKey, pressBackspace }
}
