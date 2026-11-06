#ifndef NEXCONTROL_PROTOCOL_H
#define NEXCONTROL_PROTOCOL_H

#include <stdint.h>
#include <stddef.h>

#define NEXCONTROL_MAGIC 0x4E43
#define NEXCONTROL_PROTOCOL_VERSION 1
#define NEXCONTROL_MAX_PAYLOAD_SIZE 65536

#pragma pack(push, 1)

typedef enum NexControlOpcode {
    NEXCONTROL_OP_HELLO         = 0x01,
    NEXCONTROL_OP_MANIFEST      = 0x02,
    NEXCONTROL_OP_SET_ACTIVE    = 0x03,
    NEXCONTROL_OP_DEACTIVATE    = 0x04,
    NEXCONTROL_OP_CONTROL_DELTA = 0x05,
    NEXCONTROL_OP_ACTUAL        = 0x06, // Reservado Fase 2 (MIDI Out)
    NEXCONTROL_OP_BYE           = 0x07
} NexControlOpcode;

typedef struct NexControlPacketHeader {
    uint16_t magic;          // 0x4E43
    uint8_t  version;        // 1
    uint8_t  opcode;         // NexControlOpcode
    uint32_t payload_length; // Tamanho do payload subsequente
} NexControlPacketHeader;

typedef struct NexControlHelloPayload {
    uint8_t  version;
    uint32_t client_pid;
    char     plugin_name[64];
} NexControlHelloPayload;

typedef struct NexControlParamDescWire {
    uint16_t param_idx;
    uint8_t  param_type;     // 1: Double, 2: Int, 3: Bool, 4: Choice
    uint8_t  flags;          // Bit 0: is_priority, Bit 1: is_logarithmic
    double   display_min;
    double   display_max;
    double   default_value;
    char     script_name[64];
} NexControlParamDescWire;

typedef struct NexControlManifestPayload {
    uint32_t instance_id;
    uint32_t generation;
    uint32_t param_count;
    NexControlParamDescWire params[1]; // Flexible array member
} NexControlManifestPayload;

typedef struct NexControlFocusPayload {
    uint32_t instance_id;
} NexControlFocusPayload;

// Flags para o payload CONTROL_DELTA:
#define NEXCONTROL_FLAG_CONTINUOUS_DELTA 0x01
#define NEXCONTROL_FLAG_DISCRETE_STEP    0x02
#define NEXCONTROL_FLAG_TOGGLE           0x04

typedef struct NexControlDeltaPayload {
    uint32_t instance_id;    // Identificador da instância alvo
    uint32_t generation;     // Contador de geração anti use-after-free
    uint16_t param_idx;      // Índice do parâmetro no manifesto
    uint8_t  flags;          // Tipo de ação: CONTINUOUS, DISCRETE ou TOGGLE
    uint8_t  reserved;       // Alinhamento
    double   delta_value;    // Valor delta contínuo ou passo discreto (+1.0 / -1.0)
    uint64_t timestamp_us;   // Timestamp de emissão do hardware (medição de latência)
} NexControlDeltaPayload;

typedef struct NexControlByePayload {
    uint8_t reason_code;
} NexControlByePayload;

#pragma pack(pop)

#endif // NEXCONTROL_PROTOCOL_H

