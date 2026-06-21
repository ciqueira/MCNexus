# Perguntas Frequentes

[English](../../docs/FAQ.md) · [Português](FAQ.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [Roadmap](ROADMAP.md)

## Como o MCNexus instala os plugins?

O aplicativo MCNexus instala os arquivos OFX no diretório nativo correspondente ao sistema operacional, utilizado pelos softwares de edição e correção de cor.

## Posso transferir uma licença para outro computador?

As licenças comerciais utilizam ativação vinculada ao hardware. Se o computador anterior estiver acessível, desative a licença nele antes de ativá-la no novo computador. A remoção da chave local ou dos arquivos do plugin, isoladamente, não deve ser tratada como liberação da ativação.

Se o computador anterior foi perdido, formatado ou não pode mais ser acessado, abra o formulário de [problema de ativação](https://github.com/ciqueira/MCNexus/issues/new?template=activation_problem.yml) para solicitar a análise da ativação. Nunca publique a chave completa.

## Posso usar a mesma licença em duas estações ao mesmo tempo?

Isso depende do limite de ativações definido para a licença adquirida. O Nexus não amplia esse limite automaticamente. Quando todas as ativações estiverem ocupadas, desative uma instalação acessível ou solicite suporte.

## Como funcionam as notificações de atualização?

O MCNexus consulta os lançamentos disponíveis e apresenta uma notificação quando encontra uma atualização compatível. A instalação depende da confirmação do usuário.

## Como funciona o rollback?

O histórico de lançamentos do plugin contém as versões disponíveis. A seleção da versão necessária inicia a substituição automática dos arquivos.

## Como obtenho suporte técnico?

Escolha o formulário correspondente na [Central de Suporte](https://github.com/ciqueira/MCNexus/issues/new/choose). Há formulários separados para instalação do aplicativo, instalação de plugins, ativação de licenças e suporte geral.

> **Importante:** o Nexus oferece suporte para instalação, ativação, atualização e remoção. Problemas no funcionamento do plugin devem ser reportados ao respectivo desenvolvedor. Em caso de dúvida, podemos ajudar a identificar o canal correto.

O GitHub Issues é público e indexado por mecanismos de busca. Dados pessoais e chaves de licença completas não devem ser publicados.

## Qual é a diferença entre a distribuição Comercial e OpenKey?

A distribuição comercial utiliza o Cryptlex para validação de licenças vinculadas ao hardware. O OpenKey executa a distribuição de projetos open source sem dependência de um serviço comercial de licenciamento de terceiros.

## Como obtenho uma licença OpenKey?

Utilize o link **Obter chave** disponibilizado para o plugin no [Discovery](DISCOVERY.md) ou em seu canal oficial. Esse é o único meio de emissão da licença OpenKey e exige autenticação por uma conta do GitHub com e-mail principal verificado. Se a licença já tiver sido gerada para essa conta, o mesmo link exibirá novamente a chave existente.

## Como as compras e licenças são conectadas?

O Stripe ou um parceiro de checkout integrado processa a transação. A geração da licença e o envio das credenciais pelo MailerLite são automatizados após a confirmação.

## Quais canais de lançamento são suportados?

O OpenKey pode utilizar os canais Beta, Demo e Full. A distribuição comercial utiliza somente as edições Demo e Full.

## Qual é a diferença entre desativar a licença, remover a chave e remover o plugin?

- **Desativar licença:** encerra a ativação vinculada àquela máquina, quando a operação está disponível.
- **Remover chave:** apaga a credencial armazenada localmente, sem remover necessariamente os arquivos do plugin.
- **Remover plugin:** apaga os arquivos OFX instalados, sem significar necessariamente que a ativação remota foi liberada.

Consulte o [Guia de Operação](USER_GUIDE.md) antes de trocar de computador ou reinstalar o sistema.

## O Nexus está em conformidade com as leis de proteção de dados?

O Nexus trata somente os dados necessários ao licenciamento, à entrega do produto, à segurança e ao suporte. As informações completas estão na [Política de Privacidade](../PRIVACY.md).

## Como posso fazer uma solicitação sobre dados pessoais?

A solicitação deve ser enviada para [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br). Solicitações de privacidade não devem ser publicadas no GitHub Issues.
