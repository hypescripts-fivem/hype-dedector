<template>
    <AdminDetectorDetail v-if="admin.editing" :key="admin.editing.id" :detector="admin.editing" />

    <div v-else class="flex h-full flex-col gap-3">
        <div class="flex items-center gap-2">
            <div class="relative mr-20 min-w-0 flex-1">
                <Search class="pointer-events-none absolute top-1/2 left-3 z-10 size-4 -translate-y-1/2 text-text-faint" />
                <Inputs v-model="search" size="sm" class="py-2 pl-9 text-sm" placeholder="Search name or area..." />
            </div>
            <Button size="sm" variant="solid" class="shrink-0 py-2.5" @click="creating = true">
                <Plus class="size-3.5" />
                New detector
            </Button>
        </div>

        <!-- The table gets whatever height is left; rows that don't fit go to the next page instead of scrolling -->
        <div ref="tableArea" class="min-h-0 flex-1">
            <DataTable
                v-model:sort="sort"
                v-model:page="page"
                :columns="columns"
                :rows="rows"
                :page-size="pageSize"
                :empty-text="admin.detectors.length ? 'No detectors match your search' : 'No detectors yet. Stand where one should go and create it.'"
            >
                <template #cell="{ column, row }">
                    <div v-if="column.key === 'name'" class="whitespace-nowrap leading-tight">
                        <p class="font-medium text-text-primary">{{ row.name }}</p>
                        <p class="text-xs text-text-faint">{{ row.area || "No area" }}</p>
                    </div>
                    <span v-else-if="column.key === 'categories'" class="text-text-muted">{{ row.categories }}</span>
                    <span
                        v-else-if="column.key === 'alert'"
                        class="inline-flex items-center gap-1.5 text-xs font-medium"
                        :class="row.alert ? 'text-text-primary' : 'text-text-faint'"
                    >
                        <component :is="row.alert ? BellRing : BellOff" class="size-3.5" />
                        {{ row.alert ? "On" : "Off" }}
                    </span>
                    <DetectorStatusPill v-else-if="column.key === 'status'" :status="row.status as DetectorStatus" />
                    <span v-else-if="column.key === 'alarmsToday'" class="tabular-nums" :class="Number(row.alarmsToday) ? 'text-danger' : 'text-text-faint'">
                        {{ row.alarmsToday }}
                    </span>
                    <div v-else-if="column.key === 'actions'" class="flex items-center justify-end gap-1.5">
                        <Tooltip content="Teleport" side="top">
                            <Button variant="secondary" size="sm" class="p-2" aria-label="Teleport" @click="admin.teleport(Number(row.id))">
                                <Navigation class="size-3.5" />
                            </Button>
                        </Tooltip>
                        <Tooltip :content="row.status === 'disabled' ? 'Enable' : 'Disable'" side="top">
                            <Button
                                variant="secondary"
                                size="sm"
                                class="p-2"
                                :aria-label="row.status === 'disabled' ? 'Enable' : 'Disable'"
                                @click="admin.setStatus(Number(row.id), row.status === 'disabled' ? 'active' : 'disabled')"
                            >
                                <component :is="row.status === 'disabled' ? Power : PowerOff" class="size-3.5" />
                            </Button>
                        </Tooltip>
                        <Tooltip content="Manage" side="top">
                            <Button size="sm" class="p-2" aria-label="Manage" @click="admin.openDetector(Number(row.id))">
                                <Settings class="size-3.5" />
                            </Button>
                        </Tooltip>
                    </div>
                    <template v-else>{{ row[column.key] }}</template>
                </template>
            </DataTable>
        </div>

        <AdminCreateDetector v-if="creating" @close="creating = false" />
    </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { BellOff, BellRing, Navigation, Plus, Power, PowerOff, Search, Settings } from "@lucide/vue";
import { Button, DataTable, Inputs, Tooltip, type DataTableColumn } from "@vezironi/veyra-ui";
import { useAdminStore, type DetectorStatus } from "@/stores/admin";
import AdminCreateDetector from "./AdminCreateDetector.vue";
import AdminDetectorDetail from "./AdminDetectorDetail.vue";
import DetectorStatusPill from "./DetectorStatusPill.vue";

const admin = useAdminStore();

const search = ref<string | number | undefined>("");
const sort = ref<{ key: string; direction: "asc" | "desc" } | null>(null);
const creating = ref(false);

const columns: DataTableColumn[] = [
    { key: "name", label: "Detector", sortable: true },
    { key: "categories", label: "Reacts to" },
    { key: "alert", label: "Police alert", sortable: true },
    { key: "status", label: "Status", sortable: true },
    { key: "alarmsToday", label: "Alarms today", sortable: true, align: "right" },
    { key: "actions", label: "", align: "right" },
];

const rows = computed(() => {
    const query = String(search.value ?? "").trim().toLowerCase();

    return admin.detectors
        .filter((detector) => !query || [detector.name, detector.location.label].some((value) => value.toLowerCase().includes(query)))
        .map((detector) => ({
            id: detector.id,
            name: detector.name,
            area: detector.location.label,
            categories: detector.categories.map(admin.categoryLabel).join(", "),
            alert: detector.alert,
            status: detector.status,
            alarmsToday: detector.alarmsToday,
        }));
});

// Measured from the rendered DataTable: header row plus the table border, one detector row and the pagination bar
const TABLE_HEAD = 42;
const TABLE_ROW = 58;
const TABLE_FOOTER = 46;

const tableArea = ref<HTMLElement>();
const tableHeight = ref(0);
const page = ref(1);

// The area only exists while the list is shown, so it's observed again after coming back from a detector
watch(tableArea, (element, _, onCleanup) => {
    if (!element) return;

    const observer = new ResizeObserver(([entry]) => tableHeight.value = entry?.contentRect.height ?? 0);
    observer.observe(element);
    onCleanup(() => observer.disconnect());
});

// As many rows as fit; the pagination bar only takes room once there's more than one page
const pageSize = computed(() => {
    if (!tableHeight.value) return 12;

    const fit = (space: number) => Math.max(1, Math.floor((space - TABLE_HEAD) / TABLE_ROW));
    const all = fit(tableHeight.value);

    return rows.value.length <= all ? all : fit(tableHeight.value - TABLE_FOOTER);
});

watch(search, () => page.value = 1);

// Fewer pages after resizing or searching: stay on the last one instead of an empty page
watch([pageSize, () => rows.value.length], () => {
    page.value = Math.min(page.value, Math.max(1, Math.ceil(rows.value.length / pageSize.value)));
});
</script>
