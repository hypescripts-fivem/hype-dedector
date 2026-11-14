<template>
    <div class="flex flex-col gap-3">
        <SaveBar :dirty="dirty" :error="saveError ?? error" :saving="admin.saving" @reset="reset" @save="save" />

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <ScanLine class="size-4 text-text-muted" /> Detection
            </h3>
            <SettingRow
                label="Cooldown (seconds)"
                description="How long before the same player can set off the same detector again."
            >
                <div class="w-24">
                    <Inputs
                        :model-value="draft.cooldown"
                        type="number"
                        size="sm"
                        :min="0"
                        :max="admin.limits.maxCooldown"
                        @update:model-value="draft.cooldown = toInt($event)"
                    />
                </div>
            </SettingRow>
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <ScrollText class="size-4 text-text-muted" /> Logging
            </h3>
            <SettingRow label="Log alarms" description="Keep alarm logs here, and send them with admin actions to the Discord webhook if one is set.">
                <Switch v-model="draft.logAlarms" />
            </SettingRow>
            <SettingRow label="Keep logs for (days)" description="Older alarm logs are deleted every hour.">
                <div class="w-24">
                    <Inputs
                        :model-value="draft.logRetentionDays"
                        type="number"
                        size="sm"
                        :min="1"
                        :max="admin.limits.maxRetentionDays"
                        @update:model-value="draft.logRetentionDays = toInt($event)"
                    />
                </div>
            </SettingRow>
        </section>

        <section class="flex flex-col gap-2 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <Info class="size-4 text-text-muted" /> More in the config
            </h3>
            <p class="text-xs text-text-faint">
                Which items count as metal, who gets the alerts, the alert itself, the light and the sound are set in
                <code class="rounded bg-bg-muted px-1 py-0.5 text-text-muted">config/config.lua</code>.
            </p>
            <p class="text-xs text-text-faint">
                The Discord webhook is set on the server only, in
                <code class="rounded bg-bg-muted px-1 py-0.5 text-text-muted">config/sv-config.lua</code>, so players can never read it.
            </p>
        </section>
    </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { Info, ScanLine, ScrollText } from "@lucide/vue";
import { Inputs, Switch } from "@vezironi/veyra-ui";
import SaveBar from "@/components/SaveBar.vue";
import SettingRow from "@/components/SettingRow.vue";
import { useAdminStore, type AdminSettings } from "@/stores/admin";

const admin = useAdminStore();

const clone = (settings: AdminSettings): AdminSettings => JSON.parse(JSON.stringify(settings));

const draft = ref<AdminSettings>(clone(admin.settings));
const saveError = ref<string>();

const dirty = computed(() => JSON.stringify(draft.value) !== JSON.stringify(admin.settings));

const error = computed(() => {
    const { cooldown, logRetentionDays } = draft.value;

    if (cooldown < 0 || cooldown > admin.limits.maxCooldown) {
        return `The cooldown must be between 0 and ${admin.limits.maxCooldown} seconds.`;
    }
    if (logRetentionDays < 1 || logRetentionDays > admin.limits.maxRetentionDays) {
        return `Logs can be kept for 1 to ${admin.limits.maxRetentionDays} days.`;
    }
    return undefined;
});

watch(draft, () => saveError.value = undefined, { deep: true });

function toInt(value: string | number | undefined): number {
    const number = Math.floor(Number(value));
    return Number.isFinite(number) ? number : 0;
};

function reset() {
    draft.value = clone(admin.settings);
    saveError.value = undefined;
};

async function save() {
    if (error.value) return;

    const response = await admin.saveSettings(draft.value);

    if (response.success) {
        reset();
    } else {
        saveError.value = response.error ?? "The settings could not be saved.";
    }
};
</script>
