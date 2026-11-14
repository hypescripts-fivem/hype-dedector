<script setup lang="ts">
import { defineAsyncComponent, type Component } from 'vue';
import { useAppStore, type View } from './stores/app';

const app = useAppStore();

// The admin page pulls in echarts, so it loads only when opened
const pages: Record<View, Component> = {
  admin: defineAsyncComponent(() => import('./pages/AdminView.vue')),
};
</script>

<template>
  <div class="w-screen h-screen items-center justify-center overflow-hidden flex">
    <component :is="pages[app.view]" v-if="app.visible && app.ready" />
  </div>
</template>
