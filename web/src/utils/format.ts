const dateOptions = {
    date: { month: "short", day: "numeric" },
    dateTime: { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" },
    time: { hour: "2-digit", minute: "2-digit" },
} satisfies Record<string, Intl.DateTimeFormatOptions>;

const formatters = new Map<string, Intl.DateTimeFormat>();

function dateFormatter(kind: keyof typeof dateOptions): Intl.DateTimeFormat {
    if (!formatters.has(kind)) formatters.set(kind, new Intl.DateTimeFormat("en-US", dateOptions[kind]));

    return formatters.get(kind) as Intl.DateTimeFormat;
};

// Timestamps from the server are milliseconds
export function formatDate(time: number): string {
    return dateFormatter("date").format(time);
};

export function formatDateTime(time: number): string {
    return dateFormatter("dateTime").format(time);
};

// "Today, 14:02" for today, "Oct 24, 14:02" otherwise
export function formatRelative(time: number): string {
    if (new Date(time).toDateString() === new Date().toDateString()) {
        return `Today, ${dateFormatter("time").format(time)}`;
    };

    return formatDateTime(time);
};

// Days come as "2026-10-24", read as a local date so the day never shifts with the timezone
export function formatDay(day: string): string {
    const [year, month, date] = day.split("-").map(Number);
    return formatDate(new Date(year!, month! - 1, date).getTime());
};
