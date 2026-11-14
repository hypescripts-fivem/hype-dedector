---@meta

---@alias DetectorStatus "active" | "disabled"
---@alias FeedbackResult "alarm" | "clear"

---@class CallbackResponse
---@field success boolean
---@field error? string Shown to the admin as is
---@field data? table

---@class Detector A detector as the server caches it and the clients receive it
---@field id integer
---@field name string
---@field area string Street name
---@field x number
---@field y number
---@field z number
---@field heading number
---@field categories string[] Config.Categories values it reacts to
---@field alert boolean whether its alarms go to Config.Alert.server
---@field status DetectorStatus

---@class DetectorInput What ValidateDetector returns from the admin menu's form
---@field name string
---@field area string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field categories string[]
---@field alert boolean

---@class AlertData Passed to Config.Alert.server. Never says what was found
---@field source number
---@field detector { id: integer, name: string, area: string, coords: vector3 }
---@field time integer os.time()

---@class Category
---@field value string
---@field label string
---@field items? string[]
---@field patterns? string[]

---@class InventoryItem
---@field name string
---@field count number

---@class JobInfo
---@field name string
---@field label string
---@field grade { name: string, level: integer }
---@field onDuty boolean

---@class AlarmLog
---@field id integer
---@field detectorId integer
---@field detectorName string?
---@field name string
---@field createdAt integer Milliseconds
