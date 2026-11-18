# Perguntas Frequentes

[English](../../docs/FAQ.md) · [Português](FAQ.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [Roadmap](ROADMAP.md) · [Continuidade](CONTINUITY.md)

## Para Usuário Final

### Como o MCNexus instala os plugins?

O aplicativo MCNexus instala os arquivos OFX no diretório nativo correspondente ao sistema operacional (`C:\Program Files\Common Files\OFX\Plugins` no Windows e `/Library/OFX/Plugins` no macOS).

### Como obtenho uma licença OpenKey?

Utilize o link **Obter chave** disponibilizado para o plugin no [Discovery](DISCOVERY.md) ou em seu canal oficial. Você pode se autenticar com **código por e-mail verificado**, **conta Google** ou **conta GitHub**. Se a licença já tiver sido gerada para essa identidade, o mesmo link exibirá novamente a chave existente.

### Posso transferir uma licença para outro computador?

Todas as licenças utilizam ativação vinculada ao hardware, por node-lock. Se o computador anterior estiver acessível, desative a licença nele antes de ativá-la no novo computador. A remoção da chave local ou dos arquivos do plugin, isoladamente, não libera a ativação.

Se o computador anterior foi perdido, formatado ou não pode mais ser acessado, abra o formulário de [problema de ativação](https://github.com/ciqueira/MCNexus/issues/new?template=activation_problem.yml) para solicitar a análise da ativação. Nunca publique a chave completa.

### Posso usar a mesma licença em duas estações ao mesmo tempo?

Isso depende do limite de ativações definido para a licença adquirida. O Nexus não amplia esse limite automaticamente. Quando todas as ativações estiverem ocupadas, desative uma instalação acessível ou solicite suporte.

### Como funcionam as notificações de atualização e o rollback?

O MCNexus consulta os lançamentos disponíveis e apresenta uma notificação quando encontra uma atualização compatível. A instalação depende da confirmação do usuário. Para voltar uma versão (rollback), abra o histórico de lançamentos do plugin no MCNexus e selecione a versão desejada; os arquivos são substituídos automaticamente.

### Qual é a diferença entre desativar a licença, remover a chave e remover o plugin?

- **Desativar licença:** encerra a ativação vinculada àquela máquina, quando a operação está disponível.
- **Remover chave:** apaga a credencial armazenada localmente, sem remover necessariamente os arquivos do plugin.
- **Remover plugin:** apaga os arquivos OFX instalados, sem liberar necessariamente a ativação remota.

Consulte o [Guia de Operação](USER_GUIDE.md) antes de trocar de computador ou reinstalar o sistema.

### Como obtenho suporte técnico?

Escolha o formulário correspondente na [Central de Suporte](https://github.com/ciqueira/MCNexus/issues/new/choose). Há formulários separados para instalação do aplicativo, instalação de plugins, ativação de licenças e suporte geral.

> **Importante:** o Nexus oferece suporte para instalação, ativação, atualização e remoção. Problemas no funcionamento do plugin devem ser reportados ao respectivo desenvolvedor. Em caso de dúvida, podemos ajudar a identificar o canal correto.

O GitHub Issues é público e indexado por mecanismos de busca. Dados pessoais e chaves de licença completas não devem ser publicados.

### O Nexus está em conformidade com as leis de proteção de dados?

O Nexus trata somente os dados necessários ao licenciamento, à entrega do produto, à segurança e ao suporte. As informações completas estão na [Política de Privacidade](../PRIVACY.md). Para solicitações sobre dados pessoais, escreva para [hello@mcnexus.app](mailto:hello@mcnexus.app).

---

## Para Desenvolvedor

### Onde posso embarcar a SDK NexKeyRuntime?

A `NexKeyRuntime` (`ABI 1.0`) é um núcleo único em C/C++ que pode ser embarcado de três formas: dentro de um plugin OFX/DCTL (com o aplicativo MCNexus cuidando da ativação e entrega em segundo plano), dentro de um instalador ou launcher próprio do desenvolvedor, ou diretamente em uma aplicação nativa standalone ou nó de render farm headless sem o aplicativo MCNexus no fluxo. Veja [Licenciamento e Ativação](developers/LICENSING.md).

### Preciso pagar de início ou abrir o código do meu plugin?

Não. O plano **Comunidade** é grátis sempre que o produto não cobrar do usuário final, aceitando tanto binário compilado fechado quanto projetos open-source sem obrigar o uso da SDK. Para produtos pagos, o **Comercial Start** oferece edições `Beta`, `Demo` e `Trial` ilimitadas e as primeiras **10 ativações `Full` grátis** antes de iniciar a mensalidade fixa. Veja [BINARY_LICENSE da NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime/blob/main/BINARY_LICENSE.md).

### Como as compras e licenças são conectadas?

O Stripe processa os pagamentos diretamente na conta Stripe do desenvolvedor com **0% de comissão da plataforma**. Após a confirmação, o Nexus emite ou promove a licença (atualizando chaves `Demo` ou `Trial` para `Full` automaticamente quando o comprador usa o mesmo e-mail verificado), registra o aceite legal auditável e envia a chave por e-mail transacional. Veja [Commerce e Fulfillment](developers/COMMERCE.md).

### Quais canais de lançamento e edições são suportados?

O OpenKey suporta quatro edições (`Beta`, `Demo`, `Trial` e `Full`) e separa releases `stable` de prereleases `beta` no servidor. A distribuição comercial utiliza edições `Demo`, `Trial` e `Full` (chaves `Beta` são bloqueadas contra emissão no checkout). Veja [Releases, Rollback e Avisos](developers/RELEASES.md).

### Qual é a diferença entre OpenKey e Cryptlex?

O OpenKey é o backend de licenciamento nativo do Nexus, atendendo produtos gratuitos e comerciais com a mesma experiência de cliente. O Cryptlex é um backend alternativo para desenvolvedores que já o utilizam; produtos Cryptlex são vendidos e emitidos pelo canal próprio do desenvolvedor, e emitir licenças Cryptlex direto pelo Nexus Commerce está no [roadmap](ROADMAP.md).

### Posso distribuir DCTLs como plugins OFX ou suportar controladoras MIDI?

Sim. A `NexKeyRuntime` inclui empacotamento **DCTL para OFX** (convertendo scripts `.dctl` e LUTs 3D em plugins `.ofx.bundle` nativos Metal/OpenCL sem programar C++) e o **NexControl** para mapeamento físico de hardware MIDI sem permissão de Acessibilidade. Veja [DCTL para OFX](developers/DCTL.md) e [Controle MIDI](developers/MIDI.md).

### Mantenho controle sobre chaves de assinatura e continuidade?

Sim. Nos planos Pro e SDK, o desenvolvedor gera e guarda suas próprias chaves offline de assinatura e recuperação (keyring de 4 slots com rotação sem quebra), e as estações já ativadas continuam operando offline durante qualquer interrupção do servidor. Veja [Continuidade e Recuperação](CONTINUITY.md).
