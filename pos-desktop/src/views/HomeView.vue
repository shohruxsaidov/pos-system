<template>
  <div class="home-view">
    <div class="home-center">
      <!-- Date -->
      <div class="home-date">{{ currentDate }}</div>

      <!-- Greeting -->
      <div class="home-greeting">
        {{ greeting }}, <span class="greeting-name">{{ session.user?.name }}</span>! {{ greetingEmoji }}
      </div>

      <!-- Quote card -->
      <div class="quote-card">
        <p class="quote-text">"{{ currentQuote }}"</p>
        <Button icon="pi pi-refresh" label="Новая цитата" class="p-button-text quote-btn" @click="newQuote" />
      </div>

      <!-- CTA -->
      <Button label="Открыть кассу →" class="touch-lg cta-btn" @click="router.push('/pos')" />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session.js'
import Button from 'primevue/button'

const router = useRouter()
const session = useSessionStore()

const QUOTES = [
  'Улыбка кассира — лучший чек.',
  'Я сканирую, значит существую.',
  'Каждый “бип” приближает нас к зарплате.',
  'Покупатель всегда прав... пока не пытается вернуть товар без чека.',
  'Штрихкод не найден? Как и моя мотивация.',
  'Улыбнитесь! Вы под 14 камерами наблюдения.',
  'В этой экономике важен каждый скан.',
  'Я не всегда пересчитываю наличку, но когда пересчитываю — сбиваюсь.',
  'Еще один день, еще один чек, который никто не хочет.',
  'Аннулировать транзакцию: история моей жизни.',
  'Проверка цены на аллее реальности.',
  'Моя вторая клавиатура — сканер штрихкодов.',
  'Наличные или карта? Вечный вопрос современности.',
  'Неожиданный предмет в зоне упаковки... это я.',
  'У нас не проблема. У нас фича: отрицательный остаток.',
  'Сон. Скан. Повторить.',
  'Работаю на кофе и страхе длинных очередей.',
  'Каждая продажа — маленькое чудо.',
  'Пришел, отсканировал, дал сдачу.',
  'Бонусные баллы: иллюзия экономии.'
]

const currentDate = ref('')
const greeting = ref('')
const greetingEmoji = ref('')
const currentQuote = ref('')
let clockTimer = null

function updateClock() {
  const now = new Date()
  const days = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота']
  const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря']
  currentDate.value = `${days[now.getDay()]}, ${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}`

  const h = now.getHours()
  if (h >= 5 && h < 12) { greeting.value = 'Доброе утро'; greetingEmoji.value = '☀️' }
  else if (h >= 12 && h < 17) { greeting.value = 'Добрый день'; greetingEmoji.value = '🌤️' }
  else if (h >= 17 && h < 21) { greeting.value = 'Добрый вечер'; greetingEmoji.value = '🌆' }
  else { greeting.value = 'Доброй ночи'; greetingEmoji.value = '🌙' }
}

function newQuote() {
  const idx = Math.floor(Math.random() * QUOTES.length)
  currentQuote.value = QUOTES[idx]
}

onMounted(() => {
  updateClock()
  newQuote()
  clockTimer = setInterval(updateClock, 60_000)
})

onUnmounted(() => clearInterval(clockTimer))
</script>

<style scoped>
.home-view {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: var(--gradient-mesh), var(--bg-base);
}

.home-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24px;
  max-width: 560px;
  width: 100%;
  text-align: center;
}

.home-date {
  font-size: 16px;
  color: var(--text-muted);
  font-weight: 500;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.home-greeting {
  font-size: 32px;
  font-weight: 700;
  color: var(--text-primary);
  line-height: 1.2;
}

.greeting-name {
  background: var(--gradient-hero);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.quote-card {
  background: var(--gradient-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 24px 28px 16px;
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.quote-text {
  font-size: 15px;
  color: var(--text-secondary);
  font-style: italic;
  line-height: 1.6;
  margin: 0;
}

.quote-btn {
  font-size: 13px;
  color: var(--text-muted) !important;
  padding: 6px 12px !important;
  height: auto !important;
}

.quote-btn:hover {
  color: var(--text-accent) !important;
}

.cta-btn {
  width: 100%;
  background: var(--gradient-hero) !important;
  border: none !important;
  border-radius: 14px !important;
  font-size: 20px !important;
  font-weight: 700 !important;
  box-shadow: 0 4px 24px var(--accent-glow) !important;
}

.cta-btn:hover {
  opacity: 0.9;
  transform: translateY(-1px);
  transition: all 0.15s;
}
</style>
