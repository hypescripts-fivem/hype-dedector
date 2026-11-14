<template>
    <div class="flex flex-col gap-3">
        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <ScanLine class="size-4 text-text-muted" /> Details
            </h3>
            <label class="grid gap-1.5 text-sm text-text-muted">
                Detector name
                <Inputs
                    :model-value="config.name"
                    :maxlength="admin.limits.nameLength"
                    placeholder="e.g. Del Perro Plaza entrance"
                    @update:model-value="config.name = String($event ?? '')"
                />
            </label>
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                <BellRing class="size-4 text-text-muted" /> Alerts
            </h3>
            <SettingRow
                label="Alert police and security"
                description="When off, this detector still beeps red and logs the alarm, but no alert is sent."
            >
                <Switch v-model="config.alert" />
            </SettingRow>
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <div class="flex items-center justify-between">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <MapPin class="size-4 text-text-muted" /> Location
                </h3>
                <Button variant="outline" size="sm" :disabled="locating" @click="useMyPosition">
                    <Crosshair class="size-3.5" />
                    {{ locating ? "Locating..." : "Use my position" }}
                </Button>
            </div>
            <p class="-mt-2 text-xs text-text-faint">
                Stand where the detector should be and face the way people walk through it.
            </p>
            <label class="grid gap-1.5 text-sm text-text-muted">
                Area label
                <Inputs
                    :model-value="config.location.label"
                    placeholder="e.g. Del Perro Blvd"
                    @update:model-value="config.location.label = String($event ?? '')"
                />
            </label>
            <div class="grid grid-cols-4 gap-2">
                <label v-for="axis in axes" :key="axis" class="grid gap-1 text-xs uppercase text-text-faint">
                    {{ axis }}
                    <Inputs
                        :model-value="config.location[axis]"
                        type="number"
                        size="sm"
                        @update:model-value="config.location[axis] = toNumber($event)"
                    />
                </label>
            </div>
        </section>

        <section class="flex flex-col gap-4 rounded-2xl border border-border bg-bg-surface p-4">
            <div class="flex items-center justify-between">
                <h3 class="flex items-center gap-2 text-sm font-semibold text-text-primary">
                    <Magnet class="size-4 text-text-muted" /> Reacts to
                    <span class="text-xs font-normal text-text-faint">{{ config.categories.length }} selected</span>
                </h3>
                <div class="flex items-center gap-3 text-xs">
                    <button type="button" class="text-text-faint transition-colors hover:text-text-primary" @click="config.categories = admin.categories.map((category) => category.value)">
                        Select all
                    </button>
                    <button type="button" class="text-text-faint transition-colors hover:text-text-primary" @click="config.categories = []">
                        Clear
                    </button>
                </div>
            </div>
            <p class="-mt-2 text-xs text-text-faint">
                Alerts and logs only ever say "metal detected", never which of these it was.
            </p>
            <div class="grid grid-cols-2 gap-2">
                <!-- Checkbox renders its own <label>, so the card is a div and the checkbox stops the click from toggling twice -->
                <div
                    v-for="category in admin.categories"
                    :key="category.value"
                    :class="[
                        'flex cursor-pointer items-center gap-3 rounded-lg border px-3 py-2.5 transition-colors',
                        config.categories.includes(category.value) ? 'border-text-faint bg-bg-muted' : 'border-border hover:bg-bg-muted/30',
                    ]"
                    @click="toggleCategory(category.value, !config.categories.includes(category.value))"
                >
                    <span class="min-w-0 flex-1 truncate text-sm font-medium text-text-primary">{{ category.label }}</span>
                    <span @click.stop>
                        <Checkbox
                            :model-value="config.categories.includes(category.value)"
                            :aria-label="`React to ${category.label}`"
                            @update:model-value="toggleCategory(category.value, $event)"
                        />
                    </span>
                </div>
            </div>
        </section>
    </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { BellRing, Crosshair, Magnet, MapPin, ScanLine } from "@lucide/vue";
import { Button, Checkbox, Inputs, Switch } from "@vezironi/veyra-ui";
import SettingRow from "@/components/SettingRow.vue";
import { useAdminStore, type DetectorConfig } from "@/stores/admin";

const config = defineModel<DetectorConfig>({ required: true });

const admin = useAdminStore();

const axes = ["x", "y", "z", "heading"] as const;
const locating = ref(false);

function toNumber(value: string | number | undefined): number {
    const number = Number(value);
    return Number.isFinite(number) ? number : 0;
};

function toggleCategory(value: string, checked: boolean) {
    config.value.categories = checked
        ? [...config.value.categories.filter((entry) => entry !== value), value]
        : config.value.categories.filter((entry) => entry !== value);
};

async function useMyPosition() {
    locating.value = true;

    try {
        const response = await admin.getPosition();

        if (response.success && response.data) {
            const { label, x, y, z, heading } = response.data;
            const round = (value: number) => Math.round(value * 100) / 100;

            config.value.location = {
                label: config.value.location.label || label,
                x: round(x),
                y: round(y),
                z: round(z),
                heading: round(heading),
            };
        }
    } finally {
        locating.value = false;
    }
};
</script>
