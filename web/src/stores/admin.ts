import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { asList, asNumber, asRecord, FetchNUI } from "@/utils";

export type AdminSection = 'dashboard' | 'detectors' | 'logs' | 'settings';

export type DetectorStatus = 'active' | 'disabled';

export interface DetectorLocation {
    label: string;
    x: number;
    y: number;
    z: number;
    heading: number;
};

// Editable fields, shared by the create form and the detector page
export interface DetectorConfig {
    name: string;
    location: DetectorLocation;
    categories: string[];
    // Whether its alarms alert police / security (Config.Alert.server). It beeps and logs either way
    alert: boolean;
};

export interface Detector extends DetectorConfig {
    id: number;
    status: DetectorStatus;
    alarmsToday: number;
};

// What the server sends for a detector; the panel keeps the location together
interface DetectorRow {
    id: number;
    name: string;
    area: string;
    x: number;
    y: number;
    z: number;
    heading: number;
    categories: string[];
    alert: boolean;
    status: DetectorStatus;
    alarmsToday?: number;
};

// Only who and where. What set the detector off is never sent (roleplay rules)
export interface AlarmLog {
    id: number;
    detectorId: number;
    detectorName: string | null;
    name: string;
    // Milliseconds
    createdAt: number;
};

export interface AdminSettings {
    cooldown: number;
    logRetentionDays: number;
    logAlarms: boolean;
};

export interface Category {
    value: string;
    label: string;
};

export interface Limits {
    nameLength: number;
    maxCooldown: number;
    maxRetentionDays: number;
};

// Everything the admin panel shows, sent by admin:get-data when it opens
export interface AdminData {
    detectors: DetectorRow[];
    categories: Category[];
    defaultCategories: string[];
    settings: AdminSettings;
    limits: Limits;
    stats: { total: number; active: number; alarmsToday: number };
    // Last 7 days, oldest first
    daily: { date: string; alarms: number }[];
    recent: AlarmLog[];
};

const defaultSettings: AdminSettings = { cooldown: 10, logRetentionDays: 30, logAlarms: true };
const defaultLimits: Limits = { nameLength: 64, maxCooldown: 600, maxRetentionDays: 365 };

// Browser preview only
const now = Date.now();
const minutes = (count: number) => now - count * 60_000;

function mockDays(): AdminData["daily"] {
    const alarms = [3, 5, 2, 8, 4, 6, 7];

    return alarms.map((count, index) => {
        const date = new Date(now - (alarms.length - 1 - index) * 86_400_000);
        const pad = (value: number) => String(value).padStart(2, "0");
        return { date: `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`, alarms: count };
    });
};

const mockDetectors: DetectorRow[] = [
    { id: 4, name: "Del Perro Plaza", area: "Del Perro Blvd", x: -1385.2, y: -585.4, z: 29.2, heading: 32, categories: ["firearms", "melee", "explosives"], alert: true, status: "active", alarmsToday: 3 },
    { id: 3, name: "Maze Bank Lobby", area: "Power St", x: -68.1, y: -800.6, z: 43.2, heading: 340, categories: ["firearms", "explosives"], alert: false, status: "active", alarmsToday: 1 },
    { id: 2, name: "Pillbox Hospital", area: "Elgin Ave", x: 298.4, y: -584.1, z: 42.3, heading: 70, categories: ["firearms", "melee", "explosives", "ammo"], alert: true, status: "disabled", alarmsToday: 0 },
    { id: 1, name: "Mission Row Courthouse", area: "Atlee St", x: 237.8, y: -411.2, z: 47.9, heading: 160, categories: ["firearms", "melee"], alert: true, status: "active", alarmsToday: 3 },
];

const mockNames = ["Alex Turner", "Mia Lopez", "Ray Dawson", "Nora Kim", "Leo Grant"];

const mockLogs: AlarmLog[] = Array.from({ length: 64 }, (_, index) => {
    const detector = mockDetectors[index % mockDetectors.length]!;
    return { id: 64 - index, detectorId: detector.id, detectorName: detector.name, name: mockNames[index % mockNames.length]!, createdAt: minutes(index * 47 + 3) };
});

const mockData: AdminData = {
    detectors: mockDetectors,
    categories: [
        { value: "firearms", label: "Firearms" },
        { value: "melee", label: "Knives & melee" },
        { value: "explosives", label: "Explosives" },
        { value: "ammo", label: "Ammunition" },
    ],
    defaultCategories: ["firearms", "melee", "explosives"],
    settings: defaultSettings,
    limits: defaultLimits,
    stats: { total: 4, active: 3, alarmsToday: 7 },
    daily: mockDays(),
    recent: mockLogs.slice(0, 10),
};

const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value));

function toDetector(row: DetectorRow): Detector {
    return {
        id: row.id,
        name: row.name,
        location: { label: row.area ?? "", x: row.x, y: row.y, z: row.z, heading: row.heading },
        categories: asList<string>(row.categories),
        // Older servers don't send it; detectors alert unless turned off
        alert: row.alert !== false,
        status: row.status,
        alarmsToday: asNumber(row.alarmsToday),
    };
};

export function emptyDetectorConfig(categories: string[]): DetectorConfig {
    return {
        name: "",
        location: { label: "", x: 0, y: 0, z: 0, heading: 0 },
        categories: [...categories],
        alert: true,
    };
};

export function validateDetector(config: DetectorConfig, limits: Limits): string | undefined {
    const name = config.name.trim();

    if (!name) return "Detector name can't be empty.";
    if (name.length > limits.nameLength) return `The name can be at most ${limits.nameLength} characters.`;
    if (!config.location.x && !config.location.y && !config.location.z) return "Set a location for the detector.";
    if (!config.categories.length) return "Pick at least one category.";
    return undefined;
};

export const useAdminStore = defineStore("admin", () => {
    const section = ref<AdminSection>("dashboard");
    // Detector whose page is open inside the Detectors section
    const editingId = ref<number>();
    // Detector the Alarm logs page is filtered to, 0 for all of them
    const logFilter = ref(0);
    const detectors = ref<Detector[]>([]);
    const categories = ref<Category[]>([]);
    const defaultCategories = ref<string[]>([]);
    const settings = ref<AdminSettings>(clone(defaultSettings));
    const limits = ref<Limits>(clone(defaultLimits));
    const alarmsToday = ref(0);
    const daily = ref<AdminData["daily"]>([]);
    const recent = ref<AlarmLog[]>([]);
    const saving = ref(false);

    const editing = computed(() => detectors.value.find((detector) => detector.id === editingId.value));

    const stats = computed(() => ({
        total: detectors.value.length,
        active: detectors.value.filter((detector) => detector.status === "active").length,
        disabled: detectors.value.filter((detector) => detector.status === "disabled").length,
        alarmsToday: alarmsToday.value,
    }));

    function categoryLabel(value: string): string {
        return categories.value.find((category) => category.value === value)?.label ?? value;
    };

    async function load() {
        const response = await FetchNUI<AdminData>("admin:get-data", {}, clone(mockData));
        const data = response.data;

        if (response.success && data) {
            detectors.value = asList<DetectorRow>(data.detectors).map(toDetector);
            categories.value = asList(data.categories);
            defaultCategories.value = asList(data.defaultCategories);
            settings.value = { ...defaultSettings, ...asRecord<AdminSettings>(data.settings) };
            limits.value = { ...defaultLimits, ...asRecord<Limits>(data.limits) };
            alarmsToday.value = asNumber(asRecord<AdminData["stats"]>(data.stats).alarmsToday);
            daily.value = asList(data.daily);
            recent.value = asList(data.recent);

            // The detector that was open may have been deleted since
            if (!detectors.value.some((detector) => detector.id === editingId.value)) editingId.value = undefined;
        };

        return response;
    };

    function openDetector(id: number) {
        editingId.value = id;
        section.value = "detectors";
    };

    async function getPosition() {
        return FetchNUI<DetectorLocation>("admin:get-position", {}, {
            label: "Vinewood Blvd", x: 312.4 + Math.random() * 10, y: 178.2, z: 103.8, heading: 250,
        });
    };

    async function teleport(id: number) {
        return FetchNUI("admin:teleport", { id });
    };

    // Puts the server's copy of a detector into the list, keeping today's alarm count
    function upsert(row: DetectorRow) {
        const detector = toDetector(row);
        const index = detectors.value.findIndex((entry) => entry.id === detector.id);

        if (index === -1) {
            detectors.value.unshift(detector);
        } else {
            detector.alarmsToday = detectors.value[index]!.alarmsToday;
            detectors.value[index] = detector;
        }

        return detector;
    };

    async function createDetector(config: DetectorConfig) {
        saving.value = true;

        try {
            const mock: DetectorRow = {
                id: Math.max(0, ...detectors.value.map((detector) => detector.id)) + 1,
                name: config.name, area: config.location.label, x: config.location.x, y: config.location.y, z: config.location.z,
                heading: config.location.heading, categories: config.categories, alert: config.alert, status: "active",
            };
            const response = await FetchNUI<DetectorRow>("admin:create-detector", clone(config), mock);

            if (response.success && response.data) upsert(response.data);

            return response;
        } finally {
            saving.value = false;
        }
    };

    async function updateDetector(id: number, config: DetectorConfig) {
        saving.value = true;

        try {
            const current = detectors.value.find((detector) => detector.id === id);
            const mock: DetectorRow = {
                id, name: config.name, area: config.location.label, x: config.location.x, y: config.location.y, z: config.location.z,
                heading: config.location.heading, categories: config.categories, alert: config.alert, status: current?.status ?? "active",
            };
            const response = await FetchNUI<DetectorRow>("admin:update-detector", { id, ...clone(config) }, mock);

            if (response.success && response.data) upsert(response.data);

            return response;
        } finally {
            saving.value = false;
        }
    };

    async function setStatus(id: number, status: DetectorStatus) {
        const response = await FetchNUI("admin:set-status", { id, status });
        const detector = detectors.value.find((entry) => entry.id === id);

        if (response.success && detector) detector.status = status;

        return response;
    };

    async function deleteDetector(id: number) {
        const response = await FetchNUI("admin:delete-detector", { id });

        if (response.success) {
            detectors.value = detectors.value.filter((detector) => detector.id !== id);
            recent.value = recent.value.filter((log) => log.detectorId !== id);
            if (editingId.value === id) editingId.value = undefined;
            if (logFilter.value === id) logFilter.value = 0;
        }

        return response;
    };

    // `detectorId` 0 is every detector. Pages start at 0
    async function fetchLogs(detectorId: number, page: number) {
        const pageSize = 50;
        const matching = mockLogs.filter((log) => !detectorId || log.detectorId === detectorId);
        const mock = {
            logs: matching.slice(page * pageSize, (page + 1) * pageSize),
            hasMore: matching.length > (page + 1) * pageSize,
        };

        return FetchNUI<{ logs: AlarmLog[]; hasMore: boolean }>("admin:get-logs", { detectorId, page }, mock);
    };

    async function saveSettings(next: AdminSettings) {
        saving.value = true;

        try {
            const response = await FetchNUI<AdminSettings>("admin:save-settings", next, clone(next));
            if (response.success) settings.value = { ...defaultSettings, ...asRecord<AdminSettings>(response.data ?? next) };

            return response;
        } finally {
            saving.value = false;
        }
    };

    return {
        section,
        editingId,
        logFilter,
        editing,
        detectors,
        categories,
        defaultCategories,
        settings,
        limits,
        daily,
        recent,
        saving,
        stats,
        categoryLabel,
        openDetector,
        getPosition,
        teleport,
        createDetector,
        updateDetector,
        setStatus,
        deleteDetector,
        fetchLogs,
        saveSettings,
        load,
    };
});
