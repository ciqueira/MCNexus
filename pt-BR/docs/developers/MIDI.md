# Controle por Hardware MIDI

[English](../../../docs/developers/MIDI.md) · [Português](MIDI.md)

[Início](../../README.md) · [Guia do Desenvolvedor](../DEVELOPERS.md) · [Licenciamento](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

O `NexControl` conecta controladoras MIDI físicas diretamente aos parâmetros de plugins OpenFX, sem capturar o mouse nem depender de resolução de tela ou posição de janelas.

## 1. Como Funciona

O aplicativo MCNexus hospeda o hub MIDI, traduz mensagens do hardware usando perfis de dispositivo e envia atualizações diretamente aos parâmetros das instâncias OFX ativas por um canal local de baixa latência. Como cada plugin declara seus próprios parâmetros, quem usa não precisa configurar controladoras compatíveis nem mapear cada OFX manualmente. Como não há leitura de coordenadas nem cliques simulados, o controle continua estável ao redimensionar painéis ou trocar de monitor, sem exigir permissões de Acessibilidade.

## 2. Integração com MCNexControl.h em Plugins OFX

Inclua `MCNexControl.h` da `NexKeyRuntime`, registre a tabela ordenada de parâmetros do seu plugin e conecte o callback de atualização do host para que giros de encoder e cliques de botão atualizem o Inspector e o Viewer sem travamentos. A `MCNexControl.h` também oferece agrupamento de parâmetros, paginação por bancos virtuais para controladoras com menos encoders e agrupamento de Undo no host para ajustes feitos pelo hardware. Veja [NEXCONTROL_INTEGRATION.md na NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/NEXCONTROL_INTEGRATION.md) e `examples/06-nexcontrol-ofx`.

## 3. Status na Bandeja e Foco do Nó Ativo

O MCNexus exibe o status da controladora, o plugin ativo, diagnóstico ao vivo (**Knob Activity** com canal, banco e modo do encoder) e o controle de pausar/retomar na barra de menus do macOS e na bandeja do Windows.

- **Seleção de porta MIDI por dispositivo:** habilite ou libere controladoras individuais direto pela bandeja ou barra de menus (e veja quando uma porta está `Busy` em outro programa) para conviver com outros aplicativos MIDI. Na primeira execução, o MCNexus seleciona automaticamente a primeira controladora compatível e preserva suas escolhas depois.
- **Direcionamento por foco:** as atualizações atuam apenas quando um nó OFX compatível está em foco no Inspector (**macOS** e **Windows**).
- **Silencioso em nós nativos:** em nós nativos do Resolve, o NexControl fica inativo em segundo plano e não interfere em outras ferramentas MIDI.
- **Requisito:** o acompanhamento do nó ativo exige **DaVinci Resolve Studio**.

## 4. Controladoras Suportadas e Perfis de Dispositivo

O NexControl resolve perfis de dispositivo em três camadas:

1. **Tier 1 (Pasta customizada do usuário):** arquivos de perfil `.json` colocados em `~/Library/Application Support/MCNexus/profiles` (macOS), `%APPDATA%\MCNexus\profiles` (Windows) ou no caminho definido por `MCNEXUS_PROFILES_DIR`. Perfis Tier 1 têm prioridade sobre os embutidos quando há correspondência de porta.
2. **Tier 2 (Perfis embutidos no aplicativo, automáticos):** perfis embutidos diretamente no aplicativo carregam automaticamente out of the box.
3. **Tier 3 (Fallback genérico):** qualquer outra controladora inicia no modo **`Auto-Detect`** por padrão, com submenu **Generic Encoder Mode** (`Auto-Detect`, `Absolute (0-127)`, `Two's Complement`, `Binary Offset 64`, `Sign-Magnitude / Mackie`) salvo entre sessões caso não haja um perfil instalado no Tier 1.

### Controladoras Homologadas e Download de Perfis

| Controladora | Integração | Controles e Notas de Configuração | Perfil |
| :--- | :--- | :--- | :--- |
| **DJ TechTools Midi Fighter Twister** | Embutido (Tier 2) | 16 encoders infinitos em 4 bancos com reset por clique. Plug-and-play. | Embutido |
| **Behringer X-TOUCH MINI** | Embutido (Tier 2) + Tier 1 Estendido | 8 encoders infinitos na Layer A e Layer B com reset por clique. Funciona out of the box no Standard Mode de fábrica e no MC Mode; o perfil para download adiciona suporte estendido a canais relativos. | [Baixar perfil X-TOUCH MINI](../../../site/assets/profiles/behringer_xtouch_mini.json) |
| **Intech Studio EN16 + BU16** | Perfil Tier 1 | 16 encoders infinitos com reset por clique e 16 botões táteis dedicados em uma única porta USB `Intech Studio: Grid`. Funciona com o firmware de fábrica (4 páginas) ou com layouts customizados. | [Baixar perfil EN16 + BU16](../../../site/assets/profiles/intech_studio_grid.json) |
| **Intech Studio EN16 (Sozinho)** | Perfil Tier 1 | Setup compacto de módulo único usando o perfil `Grid`. Funciona com o firmware de fábrica (4 páginas) ou layouts solo em que o clique dos encoders aciona ações de botão. | [Baixar perfil EN16](../../../site/assets/profiles/intech_studio_grid.json) |
| **Loupedeck (CT, Live, Live S, MX Creative Console)** | Perfil Tier 1 (mapeamento manual) | Dials rotativos (além da Control Wheel no CT) e botões por meio do MIDI Plugin de terceiros incluído no software Loupedeck / Logi Options+. Requer porta MIDI virtual contendo `Loupedeck` no nome e mapeamento manual único dos dials (veja a configuração abaixo). | [Baixar perfil Loupedeck](../../../site/assets/profiles/loupedeck_midi.json) |
| **Arturia BeatStep** | Perfil Tier 1 | 16 encoders infinitos e 16 pads mapeados para reset de parâmetros. | [Baixar perfil BeatStep](../../../site/assets/profiles/arturia_beatstep.json) |
| **Korg nanoKONTROL Studio** | Perfil Tier 1 | 8 encoders infinitos e cliques de botão para reset de parâmetros via USB ou Bluetooth MIDI. | [Baixar perfil nanoKONTROL Studio](../../../site/assets/profiles/korg_nanokontrol_studio.json) |
| **Elgato Stream Deck +** | Em breve ([roadmap*](../ROADMAP.md)) | 4 dials rotativos com clique, 8 teclas LCD e Touch Strip via plugin dedicado para Stream Deck. | Em breve |

### Instruções de Instalação e Configuração Rápida

#### 1. Instalando um perfil Tier 1

Baixe o perfil da sua controladora na tabela acima e salve o arquivo em `~/Library/Application Support/MCNexus/profiles` (macOS) ou `%APPDATA%\MCNexus\profiles` (Windows). Em seguida, clique no ícone do MCNexus na barra de menus ou bandeja do sistema e selecione **Reload Custom Profiles**.

#### 2. Intech Studio (EN16 + BU16 ou EN16 Sozinho)

Após instalar o perfil acima, conecte sua controladora Grid. Tanto o firmware de fábrica (4 páginas) quanto layouts customizados funcionam automaticamente sem configuração extra.

#### 3. Loupedeck (Mapeamento Manual no MIDI Plugin da Loupedeck)

O MIDI Plugin é fornecido pela Loupedeck / Logitech dentro do software deles. O MCNexus não instala nem configura esse plugin, e ainda não há preset pronto da Loupedeck publicado, então faça o mapeamento uma vez à mão:

- **macOS:** Abra o *Audio MIDI Setup*, exiba o *MIDI Studio*, habilite o **IAC Driver** e crie um barramento contendo `Loupedeck` no nome (por exemplo, `Loupedeck IAC Bus`).
- **Windows:** Crie uma porta MIDI virtual no **loopMIDI** contendo `Loupedeck` no nome (por exemplo, `Loupedeck Port`).
- **Dials:** No software da Loupedeck, atribua a cada dial uma ação de rotação do MIDI Plugin que envie `Control Change` no Canal 1, começando em `CC 1` no primeiro dial até `CC 32`.
- **Clique dos dials (reset para o padrão):** Atribua uma ação do MIDI Plugin que envie `Note On` com o mesmo número do dial (`Note On 1` para o dial em `CC 1`).
- **Conferência:** Foque um plugin compatível com NexControl no Inspector e gire um dial. A barra de menus ou bandeja do MCNexus mostra o último controle recebido; se nada aparecer, confirme que a porta virtual está selecionada no MIDI Plugin.
