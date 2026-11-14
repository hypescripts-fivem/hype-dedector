import { color } from "echarts/core";

// ECharts draws on canvas and can't read CSS variables, so resolve veyra tokens to real colors
export function token(name: string): string {
    return getComputedStyle(document.documentElement).getPropertyValue(`--color-${name}`).trim();
};

export function chartTheme() {
    return {
        primary: token("text-primary"),
        muted: token("text-muted"),
        faint: token("text-faint"),
        border: token("border"),
        surface: token("bg-surface"),
        elevated: token("bg-elevated"),
        danger: token("danger"),
        font: getComputedStyle(document.body).fontFamily,
    };
};

// Tokens can be short hex (#fff) or rgb(), so never build alpha colors by string concatenation
export function alpha(value: string, opacity: number): string {
    return color.modifyAlpha(value, opacity) ?? value;
};

export function tooltipStyle(theme = chartTheme()) {
    return {
        backgroundColor: theme.elevated,
        borderColor: theme.border,
        borderWidth: 1,
        padding: [6, 10],
        textStyle: { color: theme.primary, fontFamily: theme.font, fontSize: 12 },
        extraCssText: "border-radius: 8px; box-shadow: none;",
    };
};
