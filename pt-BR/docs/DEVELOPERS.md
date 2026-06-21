# Documentação para Desenvolvedores

[English](../../docs/DEVELOPERS.md) · [Português](DEVELOPERS.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md)

O Nexus mantém infraestrutura para licenciamento, publicação e distribuição de plugins OFX. Esta página descreve o modelo atual de integração, os requisitos esperados de um projeto e as responsabilidades compartilhadas entre a plataforma e o desenvolvedor.

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

Indicado para projetos open source distribuídos por GitHub Releases. As licenças OpenKey são obtidas exclusivamente por um link **Obter chave**, disponibilizado para cada plugin integrado.

Ao acessar o link, o usuário autoriza a identificação pela conta do GitHub. O e-mail principal verificado é utilizado para gerar a licença e exibir a chave que será inserida no MCNexus. Se o mesmo usuário acessar novamente o link, a chave já associada à conta será apresentada.

Uma conta do GitHub com e-mail principal verificado é necessária para concluir esse fluxo.

### Comercial

Plugins comerciais utilizam Cryptlex para validação criptográfica e ativação vinculada ao hardware. Stripe ou parceiros de checkout podem acionar o cadastro do cliente, a emissão da licença e a entrega transacional das credenciais.

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

## 5. Fluxo comercial automatizado

Um fluxo comercial típico funciona assim:

1. o cliente conclui a compra no Stripe ou em um parceiro de checkout;
2. o evento da transação é validado;
3. o cliente e a licença são provisionados;
4. MailerLite ou Mailchimp envia as credenciais e instruções;
5. o cliente insere a chave no MCNexus;
6. o MCNexus valida o acesso e instala o artefato correspondente.

As integrações devem tratar reenvios e eventos duplicados sem emitir licenças indevidas. Chaves, tokens, assinaturas de webhook e credenciais de serviço nunca devem ser armazenados em repositórios públicos.

## 6. Segurança e distribuição

O Nexus utiliza downloads protegidos para produtos que exigem controle de acesso. A chave de licença não deve ser incorporada a URLs públicas, logs, nomes de arquivo ou relatórios de erro.

Assinatura e verificação criptográfica de todos os pacotes distribuídos fazem parte da evolução prevista no [Roadmap](ROADMAP.md).

## 7. Integrações atuais

- **Pagamentos:** Stripe e parceiros de checkout.
- **Licenciamento:** Cryptlex e OpenKey.
- **E-mail transacional:** MailerLite e Mailchimp.
- **Lançamentos:** GitHub Releases.

## 8. Próximos passos

A relação de plugins atuais está no [Discovery](DISCOVERY.md). Projetos open source podem ser enviados pelo formulário público de sugestão.

Para integrações comerciais, entre em contato de forma privada pelo e-mail [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br). Não publique modelos comerciais, credenciais, valores ou outros detalhes confidenciais no GitHub Issues.

O kit público de integração, exemplos e especificações automatizadas permanece no [Roadmap](ROADMAP.md).
