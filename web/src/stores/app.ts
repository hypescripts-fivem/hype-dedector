import { defineStore } from "pinia";
import { ref } from "vue";
import { debug, FetchNUI, isNative } from "@/utils";

export type View = 'admin';

export const views: View[] = ['admin'];

const defaultView: View = 'admin';

function isView(value: unknown): value is View {
    return views.includes(value as View);
};

export const useAppStore = defineStore("app", () => {
    const view = ref<View>(defaultView);
    // In game nothing is on screen until the client sends setView
    const visible = ref(false);
    // Pages copy store data into their forms when they mount, so they only mount once the data is in
    const ready = ref(false);

    // Each page asks the server for its data every time it opens
    const loaders: Record<View, () => Promise<unknown>> = {
        // Imported on demand: the admin store pulls in echarts
        admin: async () => (await import("@/stores/admin")).useAdminStore().load(),
    };

    async function load(target: View) {
        ready.value = false;

        try {
            await loaders[target]();
        } finally {
            // A newer setView may have arrived while this one was loading
            if (view.value === target) ready.value = true;
        };

        debug(`setView(${target}) finished loading`, { ready: ready.value, view: view.value });
    };

    function setView(next: unknown) {
        if (!isView(next)) return;

        view.value = next;
        visible.value = true;

        debug(`setView(${next})`);

        return load(next);
    };

    // Hides the page right away; the client releases NUI focus when it gets the close callback
    function close() {
        // The browser preview has no game to come back from, so it stays on screen
        if (!isNative) return;
        if (!visible.value) return;

        visible.value = false;
        ready.value = false;
        FetchNUI("close");
    };

    // Sent by the client when it closes the page itself
    function hide() {
        visible.value = false;
        ready.value = false;
    };

    // The browser preview has no client to send setView, so it opens the admin page with mock data
    if (!isNative) {
        visible.value = true;
        load(view.value);
    }

    return {
        view,
        visible,
        ready,
        setView,
        close,
        hide,
    };
});
