# Documentação para Desenvolvedores

[English](../../docs/DEVELOPERS.md) · [Português](DEVELOPERS.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md)

O Nexus fornece infraestrutura para licenciamento, publicação e distribuição
de plugins OFX. Esta página descreve o modelo atual de integração, os requisitos
esperados de um projeto e as responsabilidades compartilhadas entre a
plataforma e o desenvolvedor.

> **Estado da documentação:** a integração ainda é acompanhada e configurada por projeto. Não existe, neste momento, uma API pública de onboarding nem um processo de publicação totalmente self-service. Formatos internos, credenciais e detalhes de segurança não são documentados publicamente.

## 1. Para quem é a integração

O Nexus atende projetos OFX que precisam de uma ou mais destas capacidades:

- instalação padronizada em macOS e Windows;
- entrega de versões e notificações de atualização;
- distribuição open source com OpenKey;
- licenciamento comercial vinculado ao hardware;
- canais Beta, Demo e Full para OpenKey;
- edições Demo e Full para distribuição comercial;
- rollback para versões anteriormente publicadas;
- automação entre checkout, emissão de licença e comunicação transacional.

O desenvolvedor continua responsável pelo código, qualidade, compatibilidade, suporte funcional e licenciamento intelectual do próprio plugin.

## 2. Modelos de distribuição

### OpenKey

O fluxo OpenKey atual é destinado a projetos open source distribuídos por
GitHub Releases. As licenças OpenKey são obtidas por um link **Obter chave**,
disponibilizado para cada plugin integrado.

Ao acessar o link, o usuário autoriza a identificação pela conta do GitHub. O e-mail principal verificado é utilizado para gerar a licença e exibir a chave que será inserida no MCNexus. Se o mesmo usuário acessar novamente o link, a chave já associada à conta será apresentada.

Uma conta do GitHub com e-mail principal verificado é necessária no fluxo
atual. Tornar o GitHub um adapter opcional de identidade e origem de releases
faz parte da evolução planejada.

### Comercial

Plugins comerciais podem utilizar o Cryptlex para validação criptográfica e
ativação vinculada ao hardware no MCNexus. A venda e a emissão da licença podem
ocorrer por um canal comercial externo. O fulfillment completo pelo Nexus
Commerce usando Cryptlex ainda não está ativo.

As condições comerciais, o número de ativações, as edições disponíveis e a política de suporte são definidos para cada produto.

## 3. Ciclo de integração

O processo começa com uma conversa sobre o plugin, as plataformas disponíveis e o modelo de distribuição. Depois, preparamos os arquivos e configuramos a publicação no Nexus.

### 3.1. Primeiro contato

Compartilhe o nome do plugin, as plataformas suportadas e se a distribuição será OpenKey ou comercial.

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

Os modelos utilizam as seguintes opções:

- **OpenKey:** Beta, Demo e Full.
- **Comercial:** Demo e Full.

O canal Beta é exclusivo do OpenKey. Demo pode ser utilizado para versões de demonstração ou avaliação, enquanto Full identifica a edição completa. Uma versão deve possuir identificação inequívoca e não deve ser substituída silenciosamente por outro binário com o mesmo número.

## 5. Fluxo Nexus Commerce atual

A composição Commerce controlada atual funciona assim:

1. o GitHub verifica a identidade e o e-mail principal do cliente;
2. o cliente conclui o pagamento pelo Stripe;
3. o Nexus valida e registra a transação;
4. o OpenKey cria ou atualiza a licença aplicável;
5. o MailerLite entrega a mensagem operacional configurada;
6. o cliente insere a chave no MCNexus, que valida o acesso e instala o
   artefato correspondente.

Produtos licenciados pelo Cryptlex podem ser distribuídos pelo MCNexus com uma
chave comercial válida, mas a emissão pelo Cryptlex ainda não faz parte desse
fluxo de fulfillment Commerce. Providers adicionais de pagamento,
licenciamento, identidade, e-mail e releases permanecem no roadmap.

As integrações devem tratar reenvios e eventos duplicados sem emitir licenças indevidas. Chaves, tokens, assinaturas de webhook e credenciais de serviço nunca devem ser armazenados em repositórios públicos.

## 6. Segurança e distribuição

O Nexus utiliza downloads protegidos para produtos que exigem controle de acesso. A chave de licença não deve ser incorporada a URLs públicas, logs, nomes de arquivo ou relatórios de erro.

Assinatura e verificação criptográfica de todos os pacotes distribuídos fazem parte da evolução prevista no [Roadmap](ROADMAP.md).

## 7. Integrações atuais

- **Identidade:** GitHub OAuth nos fluxos atuais de claim OpenKey e Commerce.
- **Pagamentos:** Stripe no fluxo Commerce controlado atual.
- **Licenciamento:** OpenKey e Cryptlex no cliente MCNexus; o fulfillment
  Commerce atual utiliza OpenKey.
- **E-mail transacional:** MailerLite.
- **Origem de releases:** GitHub Releases nos projetos OpenKey e releases
  hospedados pelo Cryptlex nos produtos configurados com esse provider.

## 8. Próximos passos

A relação de plugins atuais está no [Discovery](DISCOVERY.md). Projetos open source podem ser enviados pelo formulário público de sugestão.

Para integrações comerciais, entre em contato de forma privada pelo e-mail [hello@mcnexus.app](mailto:hello@mcnexus.app). Não publique modelos comerciais, credenciais, valores ou outros detalhes confidenciais no GitHub Issues.

O kit público de integração, a expansão de providers, a distribuição
independente do canal comercial, os exemplos e as especificações automatizadas
permanecem no [Roadmap](ROADMAP.md).
