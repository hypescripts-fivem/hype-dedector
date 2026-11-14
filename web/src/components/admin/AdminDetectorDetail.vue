<template>
    <div class="flex flex-col gap-4">
        <SaveBar :dirty="dirty" :error="saveError ?? error" :saving="admin.saving" @reset="reset" @save="save" />

        <div class="flex items-center gap-3">
            <Button variant="outline" size="sm" aria-label="Back to detectors" @click="admin.editingId = undefined">
                <ArrowLeft class="size-3.5" />
                Detectors
            </Button>
            <div class="min-w-0 leading-tight">
                <p class="flex items-center gap-2 truncate text-sm font-semibold text-text-primary">
                    {{ detector.name }}
                    <DetectorStatusPill :status="detector.status" />
                </p>
                <p class="text-xs text-text-faint">
                    #{{ detector.id }} · {{ detector.location.label || "No area" }} · {{ detector.alarmsToday }} alarm{{ detector.alarmsToday === 1 ? "" : "s" }} today
                </p>
            </div>

            <div class="ml-auto flex items-center gap-2">
                <Button variant="outline" size="sm" @click="admin.teleport(detector.id)">
                    <Navigation class="size-3.5" />
                    Teleport
                </Button>
                <Button variant="outline" size="sm" @click="showLogs">
                    <Siren class="size-3.5" />
                    Alarm logs
                </Button>
                <Button
                    :variant="detector.status === 'disabled' ? 'success' : 'warning'"
                    size="sm"
                    @click="admin.setStatus(detector.id, detector.status === 'disabled' ? 'active' : 'disabled')"
                >
                    <component :is="detector.status === 'disabled' ? Power : PowerOff" class="size-3.5" />
                    {{ detector.status === "disabled" ? "Enable" : "Disable" }}
                </Button>
            </div>
        </div>

        <DetectorForm v-model="draft" />

        <section class="flex flex-col gap-4 rounded-2xl border border-danger/30 bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-danger">
                <TriangleAlert class="size-4" /> Danger zone
            </h3>
            <SettingRow label="Delete detector" description="Removes the prop and its alarm logs for good.">
                <Button variant="danger" size="sm" @click="confirming = true">
                    <Trash2 class="size-3.5" />
                    Delete
                </Button>
            </SettingRow>
        </section>

        <Modal v-if="confirming" title="Delete detector" :icon="TriangleAlert" @close="confirming = false">
            <div class="flex flex-col gap-3 px-5 py-4 text-sm text-text-muted">
                <p>
                    This permanently deletes <b class="text-text-primary">{{ detector.name }}</b> and its alarm logs. This can't be undone.
                </p>
                <p v-if="deleteError" class="flex items-center gap-1.5 text-xs text-danger">
                    <CircleAlert class="size-3.5 shrink-0" />
                    {{ deleteError }}
                </p>
            </div>
            <template #footer>
                <Button variant="outline" size="sm" @click="confirming = false">Cancel</Button>
                <Button variant="danger" size="sm" :disabled="deleting" @click="remove">
                    {{ deleting ? "Deleting..." : "Delete detector" }}
                </Button>
            </template>
        </Modal>
    </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { ArrowLeft, CircleAlert, Navigation, Power, PowerOff, Siren, Trash2, TriangleAlert } from "@lucide/vue";
import { Button, Modal } from "@vezironi/veyra-ui";
import SaveBar from "@/components/SaveBar.vue";
import SettingRow from "@/components/SettingRow.vue";
import { useAdminStore, validateDetector, type Detector, type DetectorConfig } from "@/stores/admin";
import DetectorForm from "./DetectorForm.vue";
import DetectorStatusPill from "./DetectorStatusPill.vue";

const props = defineProps<{ detector: Detector }>();

const admin = useAdminStore();

function configOf(detector: Detector): DetectorConfig {
    const { name, location, categories, alert } = detector;
    return JSON.parse(JSON.stringify({ name, location, categories, alert }));
};

const draft = ref<DetectorConfig>(configOf(props.detector));
const saveError = ref<string>();

// Category order doesn't matter, so ticking one off and on again isn't a change
const normalized = (config: DetectorConfig) => JSON.stringify({ ...config, categories: [...config.categories].sort() });

const dirty = computed(() => normalized(draft.value) !== normalized(configOf(props.detector)));
const error = computed(() => validateDetector(draft.value, admin.limits));

watch(draft, () => saveError.value = undefined, { deep: true });

function reset() {
    draft.value = configOf(props.detector);
    saveError.value = undefined;
};

async function save() {
    if (error.value) return;

    draft.value.name = draft.value.name.trim();

    const response = await admin.updateDetector(props.detector.id, draft.value);

    if (response.success) {
        reset();
    } else {
        saveError.value = response.error ?? "The detector could not be saved.";
    }
};

function showLogs() {
    admin.section = "logs";
    admin.editingId = undefined;
    admin.logFilter = props.detector.id;
};

const confirming = ref(false);
const deleting = ref(false);
const deleteError = ref<string>();

async function remove() {
    deleting.value = true;
    deleteError.value = undefined;

    try {
        const response = await admin.deleteDetector(props.detector.id);

        if (response.success) {
            confirming.value = false;
        } else {
            deleteError.value = response.error ?? "Something went wrong.";
        }
    } finally {
        deleting.value = false;
    }
};
</script>
