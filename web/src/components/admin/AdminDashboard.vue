<template>
    <!-- A fresh server has nothing to chart, so the page points at the first step instead -->
    <EmptyState
        v-if="!admin.detectors.length"
        title="No detectors yet"
        description="Stand where the detector should go and create your first one."
        :icon="ScanLine"
        class="h-full"
    >
        <div class="mt-4 flex items-center gap-2">
            <Button variant="solid" size="sm" @click="creating = true">
                <Plus class="size-3.5" />
                New detector
            </Button>
        </div>

        <AdminCreateDetector v-if="creating" @close="creating = false" />
    </EmptyState>

    <div v-else class="flex flex-col gap-4">
        <div class="grid grid-cols-4 gap-3">
            <StatCard label="Detectors" :value="admin.stats.total" :icon="ScanLine" :change-label="`${admin.stats.active} active right now`" />
            <StatCard label="Alarms today" :value="admin.stats.alarmsToday" :icon="Siren" change-label="All detectors" />
            <StatCard label="Alarms this week" :value="weekTotal" :icon="CalendarDays" change-label="Last 7 days" />
            <StatCard label="Disabled" :value="admin.stats.disabled" :icon="PowerOff" change-label="Turned off by an admin" />
        </div>

        <div class="grid grid-cols-3 gap-3">
            <section class="col-span-2 rounded-2xl border border-border bg-bg-surface p-4">
                <header class="flex items-baseline justify-between">
                    <h3 class="text-sm font-semibold text-text-primary">Alarms</h3>
                    <span class="text-xs text-text-faint">Last 7 days</span>
                </header>
                <div class="mt-2 h-56">
                    <EChart v-if="weekTotal" :option="alarmsOption" />
                    <p v-else class="flex h-full items-center justify-center text-xs text-text-faint">No alarms in the last 7 days</p>
                </div>
            </section>

            <section class="rounded-2xl border border-border bg-bg-surface p-4">
                <header class="flex items-baseline justify-between">
                    <h3 class="text-sm font-semibold text-text-primary">Busiest today</h3>
                    <span class="text-xs text-text-faint">Alarms</span>
                </header>
                <div class="mt-2 h-56">
                    <EChart v-if="busiest.length" :option="busiestOption" />
                    <p v-else class="flex h-full items-center justify-center text-xs text-text-faint">No detector went off today</p>
                </div>
            </section>
        </div>

        <div class="grid grid-cols-2 gap-3">
            <section class="rounded-2xl border border-border bg-bg-surface">
                <header class="flex items-baseline justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">Latest alarms</h3>
                    <button
                        type="button"
                        class="text-xs text-text-faint transition-colors hover:text-text-primary"
                        @click="admin.section = 'logs'"
                    >
                        View all
                    </button>
                </header>
                <p v-if="!admin.recent.length" class="border-t border-border px-4 py-6 text-center text-xs text-text-faint">
                    No alarms yet.
                </p>
                <ul v-else class="divide-y divide-border border-t border-border">
                    <li v-for="log in admin.recent.slice(0, 5)" :key="log.id" class="flex items-center gap-3 px-4 py-2.5">
                        <Siren class="size-4 shrink-0 text-danger" />
                        <div class="min-w-0 flex-1 leading-tight">
                            <p class="truncate text-sm font-medium text-text-primary">{{ log.name }}</p>
                            <p class="truncate text-xs text-text-faint">Metal detected · {{ log.detectorName ?? "Deleted detector" }}</p>
                        </div>
                        <span class="shrink-0 text-xs tabular-nums text-text-faint">{{ formatRelative(log.createdAt) }}</span>
                    </li>
                </ul>
            </section>

            <section class="rounded-2xl border border-border bg-bg-surface">
                <header class="flex items-baseline justify-between px-4 py-3">
                    <h3 class="text-sm font-semibold text-text-primary">Newest detectors</h3>
                    <button
                        type="button"
                        class="text-xs text-text-faint transition-colors hover:text-text-primary"
                        @click="admin.section = 'detectors'"
                    >
                        View all
                    </button>
                </header>
                <ul class="divide-y divide-border border-t border-border">
                    <li v-for="detector in newest" :key="detector.id" class="flex items-center gap-3 px-4 py-2.5">
                        <div class="min-w-0 flex-1 leading-tight">
                            <p class="truncate text-sm font-medium text-text-primary">{{ detector.name }}</p>
                            <p class="truncate text-xs text-text-faint">{{ detector.location.label || "No area" }}</p>
                        </div>
                        <DetectorStatusPill :status="detector.status" />
                        <Button variant="outline" size="sm" @click="admin.openDetector(detector.id)">Open</Button>
                    </li>
                </ul>
            </section>
        </div>
    </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CalendarDays, Plus, PowerOff, ScanLine, Siren } from "@lucide/vue";
import { Button, EmptyState, StatCard } from "@vezironi/veyra-ui";
import EChart, { type ChartOption } from "@/components/EChart.vue";
import { useAdminStore } from "@/stores/admin";
import { alpha, chartTheme, tooltipStyle } from "@/utils/chart";
import { formatDay, formatRelative } from "@/utils/format";
import AdminCreateDetector from "./AdminCreateDetector.vue";
import DetectorStatusPill from "./DetectorStatusPill.vue";

const admin = useAdminStore();

const creating = ref(false);

const theme = chartTheme();

const axisLabel = { color: theme.faint, fontFamily: theme.font, fontSize: 11 };

const weekTotal = computed(() => admin.daily.reduce((sum, day) => sum + day.alarms, 0));

const newest = computed(() => admin.detectors.slice(0, 5));

const busiest = computed(() => [...admin.detectors]
    .filter((detector) => detector.alarmsToday > 0)
    .sort((a, b) => b.alarmsToday - a.alarmsToday)
    .slice(0, 5));

const alarmsOption = computed<ChartOption>(() => ({
    grid: { left: 8, right: 12, top: 12, bottom: 4, containLabel: true },
    tooltip: {
        ...tooltipStyle(theme),
        trigger: "axis",
        axisPointer: { type: "shadow", shadowStyle: { color: alpha(theme.primary, 0.04) } },
        formatter: (params: any) => {
            const day = admin.daily[params[0].dataIndex]!;
            return `<div style="color:${theme.muted}">${formatDay(day.date)}</div><b>${day.alarms} alarm${day.alarms === 1 ? "" : "s"}</b>`;
        },
    },
    xAxis: {
        type: "category",
        data: admin.daily.map((day) => formatDay(day.date)),
        axisLine: { lineStyle: { color: theme.border } },
        axisTick: { show: false },
        axisLabel,
    },
    yAxis: {
        type: "value",
        minInterval: 1,
        splitNumber: 4,
        splitLine: { lineStyle: { color: theme.border } },
        axisLabel,
    },
    series: [{
        type: "bar",
        name: "Alarms",
        data: admin.daily.map((day) => day.alarms),
        barWidth: 22,
        itemStyle: { color: theme.danger, borderRadius: [4, 4, 0, 0] },
        emphasis: { disabled: true },
    }],
}));

const busiestOption = computed<ChartOption>(() => ({
    grid: { left: 4, right: 32, top: 4, bottom: 4, containLabel: true },
    tooltip: {
        ...tooltipStyle(theme),
        trigger: "item",
        formatter: (params: any) => {
            const detector = busiest.value[params.dataIndex]!;
            return `${detector.name}<br/><b>${detector.alarmsToday} alarm${detector.alarmsToday === 1 ? "" : "s"}</b>`;
        },
    },
    xAxis: { type: "value", show: false },
    yAxis: {
        type: "category",
        inverse: true,
        data: busiest.value.map((detector) => detector.name),
        axisLine: { show: false },
        axisTick: { show: false },
        axisLabel: { ...axisLabel, color: theme.muted, width: 110, overflow: "truncate" },
    },
    series: [{
        type: "bar",
        name: "Alarms",
        data: busiest.value.map((detector) => detector.alarmsToday),
        barWidth: 12,
        itemStyle: { color: theme.primary, borderRadius: [0, 4, 4, 0] },
        emphasis: { disabled: true },
        label: {
            show: true,
            position: "right",
            color: theme.muted,
            fontFamily: theme.font,
            fontSize: 11,
        },
    }],
}));
</script>
