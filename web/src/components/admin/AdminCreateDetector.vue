<template>
    <Modal title="New detector" :icon="SquarePlus" width="44rem" @close="emit('close')">
        <!-- The form is taller than the panel, so only the body scrolls and the footer stays in reach -->
        <div class="flex max-h-[70vh] flex-col gap-3 overflow-y-auto px-5 py-4">
            <Alert v-if="createError" variant="danger" :title="createError" />

            <DetectorForm v-model="draft" />
        </div>

        <template #footer>
            <p v-if="touched && error" class="mr-auto flex items-center gap-1.5 text-xs text-danger">
                <CircleAlert class="size-3.5 shrink-0" />
                {{ error }}
            </p>
            <Button variant="outline" size="sm" @click="emit('close')">Cancel</Button>
            <Button size="sm" :disabled="!!error || admin.saving" @click="create">
                {{ admin.saving ? "Creating..." : "Create detector" }}
            </Button>
        </template>
    </Modal>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { CircleAlert, SquarePlus } from "@lucide/vue";
import { Alert, Button, Modal } from "@vezironi/veyra-ui";
import { emptyDetectorConfig, useAdminStore, validateDetector, type DetectorConfig } from "@/stores/admin";
import DetectorForm from "./DetectorForm.vue";

const emit = defineEmits<{ close: [] }>();

const admin = useAdminStore();

const blank = (): DetectorConfig => emptyDetectorConfig(admin.defaultCategories);

const draft = ref<DetectorConfig>(blank());
const createError = ref<string>();

// A fresh form is always invalid (no name yet), so the reason only shows once something was filled in
const touched = computed(() => JSON.stringify(draft.value) !== JSON.stringify(blank()));
const error = computed(() => validateDetector(draft.value, admin.limits));

async function create() {
    if (error.value) return;

    draft.value.name = draft.value.name.trim();
    createError.value = undefined;

    const response = await admin.createDetector(draft.value);

    if (response.success && response.data) {
        emit("close");
        admin.openDetector(response.data.id);
    } else {
        createError.value = response.error ?? "The detector could not be created.";
    }
};
</script>
