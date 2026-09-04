# Documentação para Desenvolvedores

[English](../../docs/DEVELOPERS.md) · [Português](DEVELOPERS.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuidade](CONTINUITY.md)

O Nexus fornece infraestrutura para licenciar, distribuir e atualizar software
nativo que precisa continuar funcionando offline. Esta página descreve o modelo
atual de integração, os requisitos esperados de um projeto e as
responsabilidades compartilhadas entre a plataforma e o desenvolvedor.

A integração documentada aqui é a de OFX, o único tipo de software em
produção. O núcleo de licenciamento não é preso a OFX, mas nenhum outro host
ou tipo de aplicação é oferecido como integração configurada ainda — ver o
[Roadmap](ROADMAP.md).

> **Estado da documentação:** a integração ainda é acompanhada e configurada por projeto. Não existe, neste momento, uma API pública de onboarding nem um processo de publicação totalmente self-service. Formatos internos, credenciais e detalhes de segurança não são documentados publicamente.

## 1. Para quem é a integração

Atualmente, o Nexus atende projetos OFX que precisam de uma ou mais destas
capacidades:

- instalação padronizada em macOS e Windows;
- entrega de versões e notificações de atualização;
- licenciamento via OpenKey, o backend nativo do Nexus — a mesma emissão de
  licença para um produto gratuito e para um pago;
- suporte a Cryptlex, como backend de licenciamento alternativo;
- edições Beta, Demo, Trial e Full no OpenKey;
- rollback para versões anteriormente publicadas;
- automação entre checkout, emissão de licença e comunicação transacional.

O desenvolvedor continua responsável pelo código, qualidade, compatibilidade, suporte funcional e licenciamento intelectual do próprio plugin.

## 2. Modelos de distribuição

Dois backends de licenciamento são suportados. O **OpenKey** é o padrão
nativo do Nexus — emite a licença de um produto gratuito e de um pago, e é
por onde o fluxo Nexus Commerce atual emite as licenças. O **Cryptlex** é
uma alternativa para desenvolvedores que já usam ele como plataforma de
licenciamento, ou que preferem um provedor terceiro dedicado em vez do
nativo do Nexus. Os dois fazem ativação vinculada ao hardware, por
node-lock — isso não é o que os diferencia.

### OpenKey

O backend nativo do Nexus. A mesma emissão serve um produto gratuito e um
pago; o que muda é como o usuário recebe a chave.

Para projetos gratuitos/open source, as licenças OpenKey são obtidas por um
link **Obter chave**, disponibilizado para cada plugin integrado. Ao acessar
o link, o usuário autoriza a identificação pela conta do GitHub. O e-mail
principal verificado é utilizado para gerar a licença e exibir a chave que
será inserida no MCNexus. Se o mesmo usuário acessar novamente o link, a
chave já associada à conta será apresentada.

Para projetos comerciais, o OpenKey também é quem emite a licença dentro do
fluxo Nexus Commerce atual — o GitHub confirma a identidade, o Stripe
processa o pagamento, o OpenKey cria ou atualiza a licença, e o MailerLite
entrega a mensagem operacional. Ver §5.

Node-lock por fingerprint de máquina, as edições Beta/Demo/Trial/Full, a
janela de validade offline e a ativação air-gap fazem parte do núcleo de
licenciamento OpenKey, seja o produto gratuito ou pago.

Uma conta do GitHub com e-mail principal verificado é necessária no fluxo
atual. Tornar o GitHub um adapter opcional de identidade e origem de releases
faz parte da evolução planejada.

### Cryptlex

Um backend alternativo para desenvolvedores que já usam o Cryptlex como
plataforma de licenciamento, ou que preferem um serviço terceiro dedicado em
vez do nativo do Nexus. Ativação vinculada ao hardware, por node-lock, não é
o que diferencia o Cryptlex — o OpenKey faz isso também (acima); a diferença
é que o Cryptlex é uma plataforma externa que alguns desenvolvedores já usam
no próprio produto, com painel e ferramentas fora do Nexus. O MCNexus valida
e ativa contra uma chave emitida pelo Cryptlex do mesmo jeito que faz com o
OpenKey.

A venda e a emissão da licença de produtos licenciados pelo Cryptlex
acontecem pelo seu próprio canal comercial externo. Edições e limites de
ativação de produtos Cryptlex são configurados na sua própria conta
Cryptlex, não pelo Nexus. Um checkout Stripe emitindo uma licença Cryptlex
automaticamente está no [roadmap](ROADMAP.md).

As condições comerciais, o número de ativações, as edições disponíveis e a política de suporte são definidos para cada produto.

## 3. Ciclo de integração

O processo começa com uma conversa sobre o plugin, as plataformas disponíveis e o modelo de distribuição. Depois, preparamos os arquivos e configuramos a publicação no Nexus.

### 3.1. Primeiro contato

Compartilhe o nome do plugin, as plataformas suportadas, se o produto é
gratuito ou comercial, e qual backend de licenciamento vai usar — OpenKey ou
Cryptlex.

### 3.2. Preparação dos arquivos

Cada versão deve fornecer um arquivo `.zip` para cada sistema operacional suportado. Use a seguinte convenção:

```text
<Produto>-macOS-<Versão>.zip
<Produto>-Windows-<Versão>.zip
```

Exemplos:

```text
MeuPlugin-macOS-1.2.0.zip
MeuPlugin-Windows-1.2.0.zip
```

Mantenha o nome do produto, a plataforma e a versão claramente identificados. Evite publicar um único arquivo para mais de uma plataforma.

O conteúdo recomendado do ZIP possui o bundle OFX na raiz:

```text
MeuPlugin-macOS-1.2.0.zip
└── MeuPlugin.ofx.bundle/
    └── Contents/
        └── MacOS/

MeuPlugin-Windows-1.2.0.zip
└── MeuPlugin.ofx.bundle/
    └── Contents/
        └── Win64/
```

Cada ZIP deve conter somente o bundle correspondente à sua plataforma, posicionado na raiz do arquivo. O nome do bundle e do executável OFX deve permanecer consistente entre versões.

### 3.3. Publicação

Com os arquivos preparados, o plugin é configurado no Nexus e testado no MCNexus. Depois da publicação, novas versões podem seguir o mesmo padrão de nomes e empacotamento.

## 4. Canais e edições

- **OpenKey:** Beta, Demo, Trial e Full — as mesmas quatro edições num projeto
  gratuito ou pago.
- **Cryptlex:** edições e limites de ativação são configurados na sua
  própria conta Cryptlex; o Nexus não os determina.

O canal Beta é exclusivo do OpenKey. Demo e Trial identificam versões de
avaliação — Trial tem prazo, Demo não — e Full identifica a edição
completa. Uma versão deve possuir identificação inequívoca e não deve ser
substituída silenciosamente por outro binário com o mesmo número.

## 5. Fluxo Nexus Commerce atual

O Commerce vende um produto pela **conta Stripe do próprio desenvolvedor**, com
a licença emitida e entregue automaticamente.

Configurado uma vez: um **catálogo de ofertas** vinculando um preço a um
produto, a conta de pagamento e as URLs de termos, privacidade e reembolso
apresentadas no checkout.

A cada venda:

1. o GitHub verifica a identidade e o e-mail principal do cliente;
2. o cliente conclui o pagamento pelo Stripe;
3. o Nexus registra o pedido, o evento de pagamento e **qual versão dos termos o
   cliente aceitou**;
4. a licença é criada ou atualizada, e a chave é entregue por **revelação
   única**, com e-mail transacional;
5. o cliente insere a chave no MCNexus, que valida o acesso e instala o
   artefato correspondente.

As tentativas de fulfillment são registradas por pedido, de modo que um evento
de pagamento reenviado ou duplicado não emite uma segunda licença.

Produtos licenciados pelo Cryptlex são distribuídos pelo MCNexus com uma chave
comercial válida, com a emissão feita na conta Cryptlex do próprio
desenvolvedor. O fulfillment por Cryptlex dentro deste fluxo, e providers
adicionais de pagamento, licenciamento, identidade, e-mail e releases, estão no
[roadmap](ROADMAP.md).

As integrações devem tratar reenvios e eventos duplicados sem emitir licenças indevidas. Chaves, tokens, assinaturas de webhook e credenciais de serviço nunca devem ser armazenados em repositórios públicos.

## 6. Segurança e distribuição

O Nexus utiliza downloads protegidos para produtos que exigem controle de acesso. A chave de licença não deve ser incorporada a URLs públicas, logs, nomes de arquivo ou relatórios de erro.

Assinatura e verificação criptográfica de todos os pacotes distribuídos fazem parte da evolução prevista no [Roadmap](ROADMAP.md).

## 7. SDK de cliente (NexKeyRuntime)

O [NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime) é a SDK pública em
C/C++14 que um produto embarca. Ela cobre descoberta de atualizações, avisos de
produto e verificação offline de um certificado de ativação — na render thread
a decisão é uma única leitura atômica, sem rede, sem I/O de arquivo e sem
parsing de JSON.

O repositório publica apenas o contrato público: o header C, os schemas JSON do
ProductData e do certificado de ativação, a documentação de integração e
exemplos. Bibliotecas estáticas compiladas para macOS (universal) e Windows x64
são publicadas como releases com checksums.

Três limites importam antes de planejar uma integração:

- **Binários compilados.** O conteúdo do próprio repositório é Apache-2.0 e
  utilizável hoje. O acesso aos releases compilados é combinado com cada
  desenvolvedor, sob a licença dos binários; o onboarding self-service está no
  [roadmap](ROADMAP.md).
- **A API está em `0.x`** e ainda pode evoluir. Os códigos de resultado são
  append-only por política e nunca são reutilizados ou renumerados.
- **Dois perfis de integração.** No Perfil A o aplicativo host (MCNexus) ativa
  a licença e o plugin a verifica localmente. No Perfil B o produto ativa e
  sincroniza por conta própria, sem o MCNexus; a SDK o implementa e as rotas do
  gateway estão em operação. A configuração dos dois passa por uma conversa
  projeto a projeto, e não por onboarding self-service.

O [Roadmap](ROADMAP.md) acompanha os três.

## 8. Providers integrados

Cada camada abaixo é separada por um contrato explícito, então um provider é
uma configuração da plataforma, e não algo embutido nela. Esta tabela é a fonte
única do que está conectado hoje; as outras páginas descrevem a camada, não o
fornecedor.

| Camada | Integrado hoje | No roadmap |
|---|---|---|
| Identidade | GitHub OAuth | E-mail e magic link, sem conta no GitHub |
| Pagamento | Stripe | Lemon Squeezy, e outros checkouts depois |
| Licenciamento | OpenKey (nativo do Nexus), Cryptlex | Keygen, LicenseSpring |
| Fulfillment do Commerce | OpenKey | Cryptlex |
| E-mail transacional | MailerLite | Um provider adicional, sob contratos separados |
| Origem de releases | GitHub Releases; releases hospedados pelo Cryptlex nos produtos configurados com ele | Storage compatível com S3, Cloudflare R2 primeiro |

Os itens de roadmap são direções, não compromisso com fornecedor ou data — o
[Roadmap](ROADMAP.md) carrega o estado atual de cada um.

## 9. Próximos passos

A relação de plugins atuais está no [Discovery](DISCOVERY.md). Projetos open source podem ser enviados pelo formulário público de sugestão.

Para integrações comerciais, entre em contato de forma privada pelo e-mail [hello@mcnexus.app](mailto:hello@mcnexus.app). Não publique modelos comerciais, credenciais, valores ou outros detalhes confidenciais no GitHub Issues.

O kit público de integração, a expansão de providers, a distribuição
independente do canal comercial, os exemplos e as especificações automatizadas
permanecem no [Roadmap](ROADMAP.md).
