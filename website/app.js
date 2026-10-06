'use strict';
const screenshots = {
  floating: { file: 'floating-bars.png', title: '浮条状态 · 浅色与深色', alt: '实际浮条状态：录音、识别、整理、取消后恢复、完成、上屏失败和识别重试，包含浅色与深色外观', width: 1680, height: 1378 },
  cleanup: { file: 'text-cleanup.png', title: '文字整理 · 模型与整理风格', alt: '实际文字整理设置：启用文字润色、方舟服务、模型和轻度润色风格', width: 1632, height: 1240 },
  models: { file: 'models.png', title: '模型配置 · 自带服务密钥', alt: '实际模型配置：豆包语音识别服务、API 密钥、识别语言和方舟文字整理服务', width: 1632, height: 1240 }
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
