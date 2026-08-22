# Guia de Operação

[English](../../docs/USER_GUIDE.md) · [Português](USER_GUIDE.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Desenvolvedores](DEVELOPERS.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuidade](CONTINUITY.md)

O MCNexus centraliza a instalação, o licenciamento e o gerenciamento de versões de plugins OFX. Este guia cobre o fluxo normal de operação e as informações necessárias para solicitar suporte com segurança.

## 1. Requisitos

- **macOS:** macOS 15 ou posterior, em Apple Silicon ou Mac Intel compatível.
- **Windows:** Windows 10 ou 11 x64. O Windows 11 ARM utiliza emulação x64.
- **Conexão com a internet:** necessária para consultar licenças, versões e downloads.
- **Permissões do sistema:** a instalação de arquivos OFX pode solicitar autorização para gravar no diretório compartilhado de plugins.

Feche os aplicativos host de OFX, como o DaVinci Resolve, antes de instalar, atualizar, retornar ou remover um plugin. Isso reduz o risco de arquivos permanecerem bloqueados durante a operação.

## 2. Instalação do MCNexus

Utilize os links oficiais disponíveis no [repositório MCNexus](../README.md). No Windows, a instalação pela <a href="https://apps.microsoft.com/detail/9n1qqt1xc825?hl=pt-BR&gl=BR" target="_blank" rel="noopener noreferrer">Microsoft Store</a> é recomendada. Um instalador `.exe` direto também está disponível no GitHub. No macOS, baixe o `.dmg` oficial pelo GitHub.

O instalador direto para Windows pode apresentar um alerta do Microsoft Defender SmartScreen porque ainda não possui assinatura de código. A versão para macOS pode apresentar um alerta do Gatekeeper porque o processo de assinatura e notarização ainda está em desenvolvimento. Não utilize instaladores enviados por terceiros.

No Windows, determinadas operações podem solicitar privilégios administrativos. No macOS, o sistema pode solicitar autorização equivalente.

## 3. Obtenção e inserção da chave

As licenças OpenKey são obtidas exclusivamente pelo link **Obter chave** disponibilizado para cada plugin no [Discovery](DISCOVERY.md) ou em seu canal oficial. O link solicita autenticação pelo GitHub e exige uma conta com e-mail principal verificado. Ao final, a chave é exibida para uso no MCNexus. Acessar novamente o mesmo link com a mesma conta retorna a chave já gerada.

Plugins comerciais fornecem a credencial conforme o processo de compra e entrega definido pelo desenvolvedor.

Ao receber a chave:

1. Abra o MCNexus.
2. Insira a chave no fluxo de adição ou ativação do plugin.
3. Confira o produto e o estado apresentado antes de iniciar a instalação.
4. Não compartilhe nem publique a chave completa.

## 4. Instalação de plugins

O MCNexus baixa o artefato correspondente ao sistema operacional e instala os arquivos no diretório OFX nativo:

- **Windows:** normalmente em `C:\Program Files\Common Files\OFX\Plugins`;
- **macOS:** normalmente em `/Library/OFX/Plugins`.

Depois da instalação, reabra o software de edição ou correção de cor para que ele faça uma nova varredura dos plugins. Se o plugin não aparecer, reinicie o aplicativo host antes de repetir a instalação.

## 5. Estados da licença

O estado exibido pelo MCNexus ajuda a identificar a próxima ação:

- **Ativa:** a licença está válida para a máquina atual.
- **Não ativa:** a chave é conhecida, mas ainda não está ativada nesta máquina.
- **Suspensa:** o uso foi suspenso pelo serviço de licenciamento e requer análise.
- **Indisponível:** não há uma ativação disponível ou a licença não pode ser utilizada naquele momento.
- **Corrompida ou com problema local:** os dados armazenados localmente não puderam ser validados.

O texto exato pode variar entre versões. Ao solicitar suporte, informe o estado mostrado e utilize a função de copiar diagnósticos, quando disponível.

## 6. Ações de licença e plugin

Estas ações têm efeitos diferentes:

- **Ativar licença:** vincula a licença à máquina atual, respeitando o limite de ativações.
- **Desativar licença:** encerra a ativação vinculada à máquina atual, quando a operação está disponível.
- **Remover chave:** apaga a credencial armazenada localmente. Isso não significa, por si só, que a ativação remota foi liberada.
- **Remover plugin:** apaga os arquivos OFX instalados. Isso não remove necessariamente a chave nem desativa a licença.

Antes de formatar, vender ou abandonar uma máquina, desative nela as licenças que pretende reutilizar.

## 7. Mudança para outro computador

Quando o computador anterior ainda está acessível:

1. Abra o MCNexus na máquina anterior.
2. Desative a licença.
3. Instale o MCNexus na nova máquina.
4. Insira a chave e faça a nova ativação.
5. Instale o plugin.

Quando a máquina anterior não estiver acessível — por perda, falha de hardware ou formatação — abra o formulário de [problema de ativação](https://github.com/ciqueira/MCNexus/issues/new?template=activation_problem.yml). Informe somente os últimos quatro caracteres da chave se uma referência for necessária.

O gerenciamento remoto e totalmente self-service de ativações ainda está no [Roadmap](ROADMAP.md).

## 8. Atualizações

O MCNexus consulta as versões publicadas e apresenta uma notificação quando encontra uma atualização compatível.

Antes de atualizar um plugin utilizado em trabalho ativo:

1. confirme que o projeto está salvo e possui backup;
2. feche o aplicativo host;
3. confira a versão que será instalada;
4. execute a atualização;
5. reabra o aplicativo e valide o plugin no projeto.

## 9. Instalação de versão anterior e rollback

Quando o histórico disponibiliza versões anteriores, selecione a versão necessária no MCNexus. O aplicativo substitui os arquivos instalados pelo artefato escolhido.

O rollback altera o binário do plugin, mas não modifica projetos nem garante que configurações criadas em versões mais novas sejam compatíveis com versões antigas. Faça backup antes de trocar a versão usada por um projeto importante.

## 10. Recuperação de falhas

Falhas de instalação, atualização ou rollback podem apresentar as ações de nova tentativa ou cancelamento. Antes de repetir:

- feche os aplicativos que possam estar utilizando o plugin;
- confirme a conexão com a internet;
- verifique se há espaço em disco;
- confirme que o sistema concedeu as permissões solicitadas;
- evite executar duas operações sobre o mesmo plugin simultaneamente.

Se a falha persistir, copie os diagnósticos antes de fechar o MCNexus.

## 11. Remoção e desinstalação

Remover um plugin pelo MCNexus apaga os arquivos OFX gerenciados pela aplicação. Desativar a licença e remover a chave são ações separadas.

Ao desinstalar o MCNexus no Windows, o instalador pode oferecer opções relacionadas aos dados locais. Plugins OFX podem permanecer instalados dependendo das escolhas realizadas. Se pretende reutilizar uma licença em outra máquina, desative-a antes de remover o aplicativo.

## 12. Suporte

> **Importante:** o Nexus oferece suporte para instalação, ativação, atualização e remoção. Problemas no funcionamento do plugin devem ser reportados ao respectivo desenvolvedor. Em caso de dúvida, podemos ajudar a identificar o canal correto.

O [GitHub Issues](https://github.com/ciqueira/MCNexus/issues/new/choose) contém formulários para:

- problemas de instalação, atualização, inicialização ou remoção do MCNexus;
- problemas de instalação, atualização, rollback ou remoção de plugins;
- problemas de ativação ou disponibilidade de licenças;
- suporte geral.

Antes de abrir o chamado, reúna:

- sistema operacional e versão;
- versão do MCNexus;
- nome e versão do plugin;
- ação executada;
- resultado esperado e comportamento observado;
- mensagem exibida;
- diagnósticos copiados pelo aplicativo, quando disponíveis.

O GitHub Issues é público e indexado por mecanismos de busca. Remova nomes, endereços de e-mail, caminhos de usuário e outros dados pessoais do diagnóstico. Chaves de licença completas não devem ser publicadas.

Solicitações de acesso, correção ou exclusão de dados pessoais devem ser enviadas de forma privada para [hello@mcnexus.app](mailto:hello@mcnexus.app).
