# Controle por Hardware MIDI (NexControl)

[English](../../../docs/developers/MIDI.md) · [Português](MIDI.md)

[Início](../../README.md) · [Guia do Desenvolvedor](../DEVELOPERS.md) · [Licenciamento](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

O `NexControl` conecta controladoras MIDI físicas diretamente aos parâmetros de plugins OpenFX com sincronização local de baixa latência, sem exigir permissões de Acessibilidade do sistema operacional.

## 1. Como o NexControl Funciona (Sem Permissões de Acessibilidade)

O aplicativo MCNexus hospeda o hub MIDI, traduz mensagens CC e Note usando perfis de dispositivo e envia atualizações de parâmetro diretamente para as instâncias OFX ativas por um canal local de baixa latência. O usuário final não precisa conceder permissões de Acessibilidade nem automação de UI.

## 2. Integração com MCNexControl.h em Plugins OFX

Inclua `MCNexControl.h` da `NexKeyRuntime`, registre a tabela ordenada de parâmetros do seu plugin e conecte o callback de atualização do host para que giros de encoder e cliques de botão atualizem o Inspector e o Viewer sem travamentos. Veja [NEXCONTROL_INTEGRATION.md na NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/NEXCONTROL_INTEGRATION.md) e `examples/06-nexcontrol-ofx`.

## 3. Perfis Embutidos vs. Perfis JSON Customizados

O NexControl resolve perfis de dispositivo em três camadas:

1. **Tier 1 (Pasta customizada do usuário):** arquivos `.json` colocados em `~/Library/Application Support/MCNexus/profiles` (macOS), `%APPDATA%\MCNexus\profiles` (Windows) ou no caminho definido por `MCNEXUS_PROFILES_DIR`. Após adicionar ou editar um arquivo, clique em **Reload Custom Profiles** na barra de menus ou bandeja do MCNexus.
2. **Tier 2 (Perfis embutidos no binário, automáticos):** perfis embutidos diretamente no binário carregam automaticamente: **Midi Fighter Twister** e **Behringer X-TOUCH MINI**.
3. **Tier 3 (Fallback genérico):** qualquer outra controladora usa mapeamento CC relativo padrão (`twos_complement` ou `binary_offset_64`) caso não haja um perfil JSON instalado no Tier 1.

### Modelos JSON de Referência (Instalar na Pasta Tier 1)

Use os modelos abaixo na sua pasta Tier 1 como ponto de partida para **Arturia BeatStep** e **Korg nanoKONTROL Studio** (compatíveis com `schemas/midi-device-profile.schema.json`):

```json
{
  "profile_version": 1,
  "vendor": "Arturia",
  "model": "BeatStep",
  "match_port_name": "BeatStep",
  "rotation_bindings": [
    {
      "bank": 1,
      "midi_channel": -1,
      "encoder_mode": "twos_complement",
      "step_sensitivity": 0.01,
      "cc_start": 20,
      "cc_end": 35,
      "param_offset": 0
    }
  ],
  "click_bindings": [
    {
      "type": "note_on",
      "midi_channel": -1,
      "index_start": 36,
      "index_end": 51,
      "param_offset": 0,
      "action": "reset_default"
    }
  ]
}
```

```json
{
  "profile_version": 1,
  "vendor": "Korg",
  "model": "nanoKONTROL Studio",
  "match_port_name": "nanoKONTROL Studio",
  "rotation_bindings": [
    {
      "bank": 1,
      "midi_channel": -1,
      "encoder_mode": "twos_complement",
      "step_sensitivity": 0.01,
      "cc_start": 16,
      "cc_end": 23,
      "param_offset": 0
    }
  ],
  "click_bindings": [
    {
      "type": "cc_value",
      "midi_channel": -1,
      "index_start": 24,
      "index_end": 31,
      "param_offset": 0,
      "trigger_values": [127],
      "action": "reset_default"
    },
    {
      "type": "note_on",
      "midi_channel": -1,
      "index_start": 24,
      "index_end": 31,
      "param_offset": 0,
      "action": "reset_default"
    }
  ]
}
```

## 4. Status na Bandeja e Foco do Nó Ativo

O MCNexus exibe status ao vivo da controladora conectada, nome do plugin ativo e controles de pausar/retomar o hub na barra de menus do macOS (`NSStatusBar`) e na bandeja do Windows (`TrayIcon`). O acompanhamento automático do nó ativo em foco opera tanto no **macOS** quanto no **Windows**, direcionando os controles físicos apenas ao plugin focado no Inspector sem exigir permissões de Acessibilidade do sistema operacional.
