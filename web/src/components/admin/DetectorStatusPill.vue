<template>
    <span class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium" :class="meta.class">
        <span class="size-1.5 rounded-full bg-current" />
        {{ meta.label }}
    </span>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { DetectorStatus } from "@/stores/admin";

const props = defineProps<{ status: DetectorStatus }>();

const statusMeta: Record<DetectorStatus, { label: string; class: string }> = {
    active: { label: "Active", class: "bg-success/10 text-success" },
    disabled: { label: "Disabled", class: "bg-danger/10 text-danger" },
};

const meta = computed(() => statusMeta[props.status]);
</script>
