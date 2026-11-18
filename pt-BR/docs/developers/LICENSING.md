# Licenciamento e Ativação

[English](../../../docs/developers/LICENSING.md) · [Português](LICENSING.md)

[Início](../../README.md) · [Guia do Desenvolvedor](../DEVELOPERS.md) · [Licenciamento](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

## 1. Modelos de Licenciamento (OpenKey e Cryptlex)

O MCNexus suporta dois backends de licenciamento node-lock vinculados ao hardware através da mesma experiência de cliente:

- **OpenKey (nativo):** emite chaves gratuitas e comerciais (`Beta`, `Demo`, `Trial` e `Full`), controla o limite configurável de máquinas por licença, permite devolução de vaga em autoatendimento e conecta-se diretamente ao Nexus Commerce para promoções automáticas na mesma chave.
- **Cryptlex:** backend alternativo para desenvolvedores que já operam o Cryptlex. Os produtos são vendidos e emitidos pelo canal próprio do desenvolvedor enquanto o MCNexus assume instalação no desktop, updates e rollback.

## 2. Integração com NexKeyRuntime e Onde Embarcar

A `NexKeyRuntime` é uma biblioteca nativa em C/C++ com ABI C estável (`ABI 1.0`, compatível em toda a série `1.x`) para macOS universal (`arm64` + `x86_64`) e Windows (`x64`, `x86`, `arm64`). Headers públicos, JSON Schemas, exemplos e binários (`BINARY_LICENSE.md`) estão publicados em [ciqueira/NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime).

1. **Embarcada no plugin OFX/DCTL:** chame `nexkeyruntime_license_load_local()` ao carregar o plugin e `nexkeyruntime_license_render_decision()` no callback de render (leitura atômica `< 1 ns` em RAM, sem locks, sem rede e sem I/O de disco).
2. **Embarcada em distribuidor próprio ou aplicação standalone:** execute `nexkeyruntime_license_activate()`, `nexkeyruntime_license_request_sync()` e `nexkeyruntime_license_deactivate()` em threads de trabalho em segundo plano, e use `nexkeyruntime_license_set_headless()` em nós de render farm ou ferramentas CLI sem interface gráfica.

## 3. Contrato de Handoff e Snapshot

Após o intake do projeto, o MCNexus provisiona seu `tenant_id`, o keyring de assinatura e o blob assinado `ProductData` (keyring público + URL base do gateway, seguro para repositórios públicos).

- **Struct C `NexKeyRuntimeLicenseSnapshot` (`nexkeyruntime.h`):** expõe `status`, `decision`, `last_error`, `activated_at`, `expires_at` (`0` para perpétua), `days_remaining` (`-1` para perpétua), `sync_after`, `offline_valid_until`, `last_synced_at`, `activations_used`, `max_activations`, `edition` e `edition_enum` (`NEXKEYRUNTIME_EDITION_BETA`, `DEMO`, `TRIAL`, `FULL`).
- **Ciclo de edições:** `Beta` é restrita a testers convidados e bloqueada no checkout; `Demo` não expira e permite ler `edition_enum` para aplicar marca d'água ou limite de função; `Trial` inicia a contagem regressiva na primeira ativação conforme o parâmetro `trial_days` da oferta no backend; `Full` libera o acesso completo.

## 4. Janela Offline e Arquivos Air-Gap (.req / .lic)

Cada certificado Ed25519 assinado carrega dois prazos independentes no JSON (`syncAfter` e `offlineValidUntil`):

- **`syncAfter`** (`sync_after` em C): quando a renovação em segundo plano começa a tentar atualizar o certificado (padrão 24 horas).
- **`offlineValidUntil`** (`offline_valid_until` em C): limite rígido aplicado localmente pela SDK (padrão 30 dias, configurável até 365 dias). O emissor garante que a janela offline cubra múltiplas tentativas de renovação.

Em estações isoladas sem internet, exporte uma requisição de ativação (`.req`), assine pelo gateway ou pela chave de recuperação gerando um certificado `.lic` e importe offline. A devolução de vaga usa o mesmo fluxo por arquivo.

## 5. Keyring de Assinatura (4 Slots) e Chave de Recuperação

Cada keyring de tenant comporta até **4 chaves públicas Ed25519**, permitindo rotação de chave sem quebrar instalações existentes. Nos planos Comercial Pro e Comercial SDK, o desenvolvedor gera e mantém suas próprias chaves offline de assinatura e recuperação: a metade privada nunca passa pelos servidores do Nexus, permitindo emitir certificados de emergência sem depender da infraestrutura da plataforma. Veja [Continuidade e Recuperação](../CONTINUITY.md).
