'use strict';
const screenshots = {
  cleanup: { file: 'cleanup-detail.jpg', title: '文字整理 · 正式版实拍', alt: '正式版文字整理设置实拍：启用文字润色、方舟模型及轻度润色风格', width: 1120, height: 640 },
  interaction: { file: 'interaction-detail.jpg', title: '录音交互 · 正式版实拍', alt: '正式版录音交互设置实拍：Fn 快捷键、按一下开始结束、剪贴板自动粘贴', width: 1120, height: 620 },
  models: { file: 'models-detail.jpg', title: '语音识别 · 正式版实拍', alt: '正式版语音识别设置实拍：豆包语音、密钥类型、识别语言和中文输出偏好', width: 1120, height: 570 }
};
const tabs = Array.from(document.querySelectorAll('[data-shot]'));
function selectScreenshot(tab) {
  tabs.forEach(item => {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
  });
  const shot = screenshots[tab.dataset.shot];
  const image = document.querySelector('#gallery-image');
  image.src = 'assets/' + shot.file;
  image.alt = shot.alt;
  image.width = shot.width;
  image.height = shot.height;
  const link = document.querySelector('#gallery-link');
  link.href = image.src;
  link.dataset.zoom = shot.title;
  document.querySelector('#gallery-caption').textContent = shot.title;
  document.querySelector('#screenshot-panel').setAttribute('aria-labelledby', tab.id);
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectScreenshot(tab));
  tab.addEventListener('keydown', event => {
    let next;
    if (event.key === 'ArrowRight' || event.key === 'ArrowDown') next = (index + 1) % tabs.length;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') next = (index + tabs.length - 1) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;
    if (next === undefined) return;
    event.preventDefault();
    selectScreenshot(tabs[next]);
    tabs[next].focus();
  });
});
const viewer = document.querySelector('#image-viewer');
if (typeof viewer.showModal === 'function') {
  document.querySelectorAll('[data-zoom]').forEach(link => {
    link.addEventListener('click', event => {
      event.preventDefault();
      const source = link.querySelector('img');
      const image = document.querySelector('#viewer-image');
      image.src = source.src;
      image.alt = source.alt;
      document.querySelector('#viewer-title').textContent = link.dataset.zoom;
      viewer.showModal();
      document.body.classList.add('viewer-open');
    });
  });
  document.querySelector('#close-viewer').addEventListener('click', () => viewer.close());
  viewer.addEventListener('click', event => { if (event.target === viewer) viewer.close(); });
  viewer.addEventListener('close', () => document.body.classList.remove('viewer-open'));
}

// A finite explanatory animation, not live recording or an AI result.
const flowButtons = Array.from(document.querySelectorAll('[data-step]'));
const flowImage = document.querySelector('#flow-bar');
const flowStatus = document.querySelector('#flow-status');
const flowOutput = document.querySelector('#flow-output');
const cleanup = document.querySelector('#flow-cleanup');
const play = document.querySelector('#play-flow');
const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
const rawWords = '嗯，突然想去海边，什么也不安排，就走走。';
const cleanWords = '突然想去海边。什么也不安排，就走走。';
let flowTimer;
function selectStep(step) {
  const states = ['recording', cleanup.checked ? 'polishing' : 'transcribing', 'completed'];
  const labels = ['按 Fn，开始说', cleanup.checked ? '结束录音，按需整理口语' : '结束录音，识别你的原话', '文字输入到光标所在的位置'];
  flowImage.src = `assets/bars/${states[step]}-light.png`;
  flowImage.alt = ['应用真实录音浮条', cleanup.checked ? '应用真实整理浮条' : '应用真实识别浮条', '应用真实完成浮条'][step];
  flowImage.removeAttribute('width');
  flowStatus.textContent = labels[step];
  flowOutput.textContent = step < 2 ? rawWords : (cleanup.checked ? cleanWords : rawWords);
  flowOutput.classList.toggle('is-waiting', step < 2);
  flowButtons.forEach((button,index) => button.setAttribute('aria-pressed',String(index === step)));
}
function stopFlow() { clearTimeout(flowTimer); play.textContent = '再看一次 ↗'; }
flowButtons.forEach(button => button.addEventListener('click', () => { stopFlow(); selectStep(Number(button.dataset.step)); }));
cleanup.addEventListener('change', () => { stopFlow(); selectStep(2); });
play.addEventListener('click', () => {
  stopFlow();
  if (innerWidth <= 800) document.querySelector('#voice-story').scrollIntoView({behavior:motion.matches ? 'instant' : 'smooth',block:'center'});
  if (motion.matches) { selectStep(2); return; }
  selectStep(0);
  play.textContent = '重新播放 ↗';
  flowTimer = setTimeout(() => { selectStep(1); flowTimer = setTimeout(() => { selectStep(2); stopFlow(); },1400); },1700);
});
const themeToggle = document.querySelector('#bar-theme');
themeToggle.addEventListener('click', () => {
  const dark = themeToggle.getAttribute('aria-pressed') !== 'true';
  themeToggle.setAttribute('aria-pressed',String(dark));
  themeToggle.textContent = dark ? '查看浅色浮条' : '查看深色浮条';
  document.querySelector('.native-states').classList.toggle('is-dark',dark);
  document.querySelectorAll('[data-bar]').forEach(img => { img.src = `assets/bars/${img.dataset.bar}-${dark ? 'dark' : 'light'}.png`; });
});
