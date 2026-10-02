# Documentação para Desenvolvedores

[English](../../docs/DEVELOPERS.md) · [Português](DEVELOPERS.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuidade](CONTINUITY.md)

O Nexus fornece infraestrutura para licenciar, distribuir e atualizar
software. Esta página é o roteiro comum de entrada e handoff para
desenvolvedores: reúne as informações necessárias para avaliar o projeto,
configurar o tenant e retornar os valores específicos para integrar o
NexKeyRuntime.

Use o mesmo intake para plugins, aplicativos desktop e outros produtos. A
integração OFX é a única integração de host atualmente em produção. Outros
hosts e tipos de produto podem ser propostos, mas passam por avaliação técnica
antes de confirmarmos suporte ou prazo; consulte o [Roadmap](ROADMAP.md).

> **Processo atual:** as integrações são avaliadas e configuradas manualmente,
> por projeto. Ainda não existe uma API pública de onboarding nem criação
> self-service de tenants. O roteiro abaixo é uma coleta inicial, não uma
> promessa de que todo host, provider ou fluxo solicitado já seja suportado.

## 1. Intake do projeto

Envie as informações abaixo por um canal privado ou por e-mail para [hello@mcnexus.app](mailto:hello@mcnexus.app). Marque como `N/A` o que não
se aplicar; dados de pagamento, jurídicos e de releases só são necessários
quando o serviço correspondente fizer parte da integração solicitada.

### Formulário para copiar e preencher

```text
Desenvolvedor / organização:
Contato técnico e e-mail:
Nome do produto e breve descrição:
Site do produto (se houver):

Tipo de produto: plugin / aplicativo desktop / outro
Aplicativo(s) host e versões:
Sistemas operacionais e arquiteturas:
Linguagem e sistema de build:
Versão atual do produto e data prevista para teste:

Serviços Nexus desejados: licenciamento / updates / avisos / downloads / commerce
Integração de licença: Perfil A (MCNexus ativa) / Perfil B (produto ativa) / indefinido / N/A
Provedor de licenciamento: OpenKey / Cryptlex / outro / indefinido
Modelo do produto: gratuito / pago / ambos
Edições, limites de ativação e o que cada edição inclui:
Entitlements ou variantes e o que cada uma libera:

Provedor de releases:
URL do repositório ou das releases (se aplicável):
Visibilidade do repositório: público / privado / N/A
URL da primeira release ou artefato de teste:
Formatos e nomes dos arquivos de release:
Canais de release: stable / beta / outro

Fluxo atual de licença/clientes (se houver):
Necessidade de uso offline ou air-gapped:
Outras necessidades para a primeira integração:
```

Não inclua senhas, chaves de licença, tokens de acesso, chaves de assinatura
ou outros segredos neste formulário. Se usar um repositório GitHub privado, o
acesso será combinado separadamente com um token granular limitado àquele
repositório e à permissão `Contents: Read-only`, compartilhado por um canal
seguro aprovado. Repositórios públicos não precisam de token de release.

O desenvolvedor continua responsável pelo código, qualidade, compatibilidade,
suporte funcional e licenciamento intelectual do próprio produto.

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

O processo começa com a análise do formulário do projeto e a confirmação do
que já é suportado. Depois, definimos o perfil de integração, configuramos o
tenant, trocamos os valores de handoff da SDK descritos em §7 e testamos uma
release real antes de concluir o onboarding.

### 3.1. Primeiro contato

Preencha o [formulário do projeto em §1](#1-intake-do-projeto). Podemos fazer
perguntas adicionais se o host, perfil de licenciamento, provider ou formato
de release solicitado precisar de avaliação técnica.

### 3.2. Preparação dos arquivos

As regras de empacotamento abaixo se aplicam à integração OFX atual. Para
outros tipos de produto, os formatos suportados são definidos durante a
avaliação técnica. Para OFX, cada versão deve fornecer um artefato para cada
sistema operacional suportado. O macOS aceita `.zip` ou `.pkg`; o Windows
requer `.zip`. Use a seguinte convenção de nomes:

```text
<Produto>-macOS-<Versão>.zip
<Produto>-macOS-<Versão>.pkg
<Produto>-Windows-<Versão>.zip
```

Exemplos:

```text
MeuPlugin-macOS-1.2.0.zip
MeuPlugin-macOS-1.2.0.pkg
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

Para um `.pkg` de macOS, o MCNexus expande o pacote em uma pasta temporária e procura diretórios `.ofx.bundle` no payload. Ele não executa scripts de instalação do pacote. O bundle deve ser autocontido e instalável por cópia para o diretório de plugins OFX; pacotes que dependem de scripts de instalação não são suportados.

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

## 7. NexKeyRuntime: integração e handoff

O [NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime) é a SDK pública em
C/C++14 que um produto embarca. Ela cobre descoberta de atualizações, avisos de
produto e verificação offline de um certificado de ativação — na render thread
a decisão é uma única leitura atômica, sem rede, sem I/O de arquivo e sem
parsing de JSON.

O repositório publica apenas o contrato público: o header C, os schemas JSON do
O repositório publica o contrato público: o header C, schemas JSON,
documentação de integração e exemplos. As bibliotecas oficiais compiladas são
distribuídas separadamente sob a
[licença dos binários](https://github.com/ciqueira/NexKeyRuntime/blob/main/BINARY_LICENSE.md).
Confirme os termos aplicáveis e o acesso aos binários das plataformas
necessárias durante a configuração do projeto; o repositório público de código
por si só não concede um tenant nem acesso ao backend.

### 7.1. Escolha do perfil de integração

- **Perfil A — MCNexus ativa.** O cliente insere ou obtém a licença no
  MCNexus. O host ativa e grava um recibo local; o produto incorpora o
  NexKeyRuntime para verificar esse recibo e tomar a decisão local de licença.
  Este é o perfil comum para plugins.
- **Perfil B — o produto ativa.** O próprio produto coleta a chave de licença
  e chama a API de ativação da SDK. A escolha exige uma avaliação explícita do
  backend e do fluxo do usuário.

O handle de updates e avisos da SDK é independente dos dois perfis de
licenciamento. Um produto pode solicitar verificação de licença, updates e
avisos, ou ambos.

### 7.2. O que o MCNexus retorna para a integração

Depois de definidos o tenant e a configuração do produto, o desenvolvedor
recebe os valores aplicáveis ao projeto por um canal privado:

- **`tenant_id`** — identificador exato do tenant que deve ser passado à SDK.
- **`ProductData`** — configuração assinada do produto, com o endereço base
  do serviço e o keyring de chaves públicas. Não contém chave privada de
  assinatura e pode ser incorporado ao produto, inclusive em um repositório
  público.
- **`variant` / entitlement** — valor exato para passar a
  `nexkeyruntime_license_set_variant()`, por exemplo
  `download:sample`. Deve corresponder ao entitlement configurado para o
  produto e para a licença; não é inferido do `ProductData`.
- **Configuração de updates/avisos, se solicitada** — `artifact_id`,
  `base_url` do serviço e os valores acordados de plataforma, arquitetura,
  canal e versão. Esses campos são separados do `variant` da licença.
- **Detalhes dos binários da SDK, se necessários** — release/versão oficial,
  bibliotecas das plataformas aplicáveis e checksums, licença dos binários e
  instruções de build e integração correspondentes.
- **Configuração testada** — perfil verificado, fluxo de ativação esperado e
  release/artefato usado no teste da integração.

O mesmo `ProductData` pode ser reutilizado entre variantes de um tenant, mas a
SDK ainda precisa receber o `tenant_id` e o `variant` exatos em runtime. Para o
handle de updates, use seu próprio `artifact_id` e os metadados de release
conforme o guia da SDK.

Nunca envie nem incorpore uma chave privada de assinatura do tenant, uma
credencial de backend ou um segredo de serviço. O MCNexus não precisa entregar
esses segredos para integrar a SDK.

Três pontos importam antes de planejar uma integração:

- **A API é estável desde a `1.0`.** Função, layout de struct ou código de
  resultado que já existe nunca muda de um jeito que quebre um binário já
  compilado: em `1.x` só entra mudança aditiva, e quebra de compatibilidade
  exigiria `2.0`. Os códigos de resultado são append-only e nunca são
  reutilizados nem renumerados.

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
