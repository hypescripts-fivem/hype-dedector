<template>
    <div class="flex flex-col gap-3">
        <div class="flex items-end gap-3">
            <div class="w-72">
                <SelectMenu v-model="filter" label="Detector" :options="filterOptions" />
            </div>
            <p class="ml-auto pb-2 text-xs text-text-faint">
                Logs only record that metal was detected, never what it was.
            </p>
        </div>

        <section class="rounded-2xl border border-border bg-bg-surface">
            <header class="grid grid-cols-[1fr_1fr_1fr_10rem] gap-4 border-b border-border px-4 py-2.5 text-xs font-medium text-text-faint">
                <span>Player</span>
                <span>Detector</span>
                <span>Result</span>
                <span class="text-right">Time</span>
            </header>

            <p v-if="loading && !logs.length" class="px-4 py-10 text-center text-xs text-text-faint">Loading...</p>
            <p v-else-if="error" class="flex items-center justify-center gap-1.5 px-4 py-10 text-xs text-danger">
                <CircleAlert class="size-3.5" />
                {{ error }}
            </p>
            <p v-else-if="!logs.length" class="px-4 py-10 text-center text-xs text-text-faint">No alarms logged.</p>

            <ul v-else class="divide-y divide-border">
                <li v-for="log in logs" :key="log.id" class="grid grid-cols-[1fr_1fr_1fr_10rem] items-center gap-4 px-4 py-2.5 text-sm">
                    <span class="truncate font-medium text-text-primary">{{ log.name }}</span>
                    <button
                        v-if="admin.detectors.some((detector) => detector.id === log.detectorId)"
                        type="button"
                        class="truncate text-left text-text-muted transition-colors hover:text-text-primary"
                        @click="admin.openDetector(log.detectorId)"
                    >
                        {{ log.detectorName }}
                    </button>
                    <span v-else class="truncate text-text-faint">{{ log.detectorName ?? "Deleted detector" }}</span>
                    <span class="inline-flex items-center gap-1.5 text-xs font-medium text-danger">
                        <Siren class="size-3.5" />
                        Metal detected
                    </span>
                    <span class="text-right text-xs tabular-nums text-text-faint">{{ formatRelative(log.createdAt) }}</span>
                </li>
            </ul>

            <div v-if="hasMore" class="flex justify-center border-t border-border p-3">
                <Button variant="outline" size="sm" :disabled="loading" @click="loadPage(page + 1)">
                    {{ loading ? "Loading..." : "Load more" }}
                </Button>
            </div>
        </section>
    </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { CircleAlert, Siren } from "@lucide/vue";
import { Button, SelectMenu } from "@vezironi/veyra-ui";
import { useAdminStore, type AlarmLog } from "@/stores/admin";
import { asList } from "@/utils";
import { formatRelative } from "@/utils/format";

const admin = useAdminStore();

const logs = ref<AlarmLog[]>([]);
const page = ref(0);
const hasMore = ref(false);
const loading = ref(false);
const error = ref<string>();

const filterOptions = computed(() => [
    { label: "All detectors", value: "0" },
    ...admin.detectors.map((detector) => ({ label: detector.name, value: String(detector.id) })),
]);

// SelectMenu works with strings, the store keeps the detector id
const filter = computed({
    get: () => String(admin.logFilter),
    set: (value: string) => admin.logFilter = Number(value) || 0,
});

// A newer request (filter changed while loading) wins over an older one
let request = 0;

async function loadPage(next: number) {
    const current = ++request;
    loading.value = true;
    error.value = undefined;

    try {
        const response = await admin.fetchLogs(admin.logFilter, next);
        if (current !== request) return;

        if (response.success && response.data) {
            const received = asList<AlarmLog>(response.data.logs);
            logs.value = next === 0 ? received : [...logs.value, ...received];
            hasMore.value = response.data.hasMore === true;
            page.value = next;
        } else {
            error.value = response.error ?? "The logs could not be loaded.";
        }
    } finally {
        if (current === request) loading.value = false;
    }
};

watch(() => admin.logFilter, () => loadPage(0));

onMounted(() => loadPage(0));
</script>
