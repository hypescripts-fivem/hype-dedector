import { LayoutDashboard, ScanLine, Settings, Siren } from "@lucide/vue";
import type { PanelSection } from "@/components/PanelSidebar.vue";
import type { AdminSection } from "@/stores/admin";

export const sections: PanelSection<AdminSection>[] = [
    { value: "dashboard", label: "Overview", description: "Server-wide metal detector activity.", icon: LayoutDashboard },
    { value: "detectors", label: "Detectors", description: "Every walk-through detector on the server.", icon: ScanLine },
    { value: "logs", label: "Alarm logs", description: "Who set off which detector, and when.", icon: Siren },
    { value: "settings", label: "Settings", description: "Global rules for all detectors.", icon: Settings },
];
