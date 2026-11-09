#ifndef NEXCONTROL_HUB_H
#define NEXCONTROL_HUB_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(NEXCONTROL_HUB_SHARED)
#    define NEXCONTROL_HUB_API __declspec(dllexport)
#  else
#    define NEXCONTROL_HUB_API
#  endif
#else
#  define NEXCONTROL_HUB_API __attribute__((visibility("default")))
#endif

#pragma pack(push, 8)

typedef struct NexControlDeviceInfo {
    uint32_t struct_size;       // Tamanho da estrutura para protecao de ABI
    char     port_id[64];       // Identificador da porta no SO
    char     display_name[64];  // Nome legivel da controladora
    char     profile_model[64]; // Modelo associado (ex: "Midi Fighter Twister")
    uint8_t  profile_tier;      // 1 = Custom JSON, 2 = Built-in Homologated, 3 = Generic Fallback
    uint8_t  _reserved[3];
} NexControlDeviceInfo;

typedef struct NexControlTelemetrySnapshot {
    size_t   struct_size;
    uint64_t packets_received;
    uint64_t deltas_applied;
    double   p99_latency_ms;
    uint32_t active_instances;
    uint8_t  midi_connected;
    char     midi_device_name[64];
    uint8_t  client_connected;
    char     client_plugin_name[64];
    uint32_t active_node_id;
    uint8_t  last_cc;
    int8_t   last_delta;
    uint64_t total_ticks;
    uint64_t last_activity_timestamp_ms;
} NexControlTelemetrySnapshot;

#pragma pack(pop)

NEXCONTROL_HUB_API int32_t nexcontrol_hub_start(const char* socket_path);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_stop(void);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_set_active_node(uint32_t instance_id);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_get_telemetry(NexControlTelemetrySnapshot* out_snapshot);

NEXCONTROL_HUB_API uint32_t nexcontrol_hub_get_device_count(void);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_get_device_info(uint32_t index, NexControlDeviceInfo* out_info);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_set_generic_encoder_mode(uint8_t encoder_mode);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_reload_profiles(const char* custom_dir_path);
NEXCONTROL_HUB_API int32_t nexcontrol_hub_inject_raw_midi(const char* port_id, const uint8_t* bytes, size_t len);

#ifdef __cplusplus
}
#endif

#endif // NEXCONTROL_HUB_H

