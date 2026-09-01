# Continuidade e Recuperação

[English](../../docs/CONTINUITY.md) · [Português](CONTINUITY.md)

[Início](../README.md) · [Discovery](DISCOVERY.md) · [Guia de Operação](USER_GUIDE.md) · [Desenvolvedores](DEVELOPERS.md) · [Roadmap](ROADMAP.md) · [FAQ](FAQ.md)

Última atualização: 1º de setembro de 2026

Este documento responde a uma pergunta: **o que acontece com os clientes de um
desenvolvedor se o Nexus for interrompido, encerrado ou deixar de ser
operado?**

Ele é escrito para desenvolvedores que avaliam o Nexus como infraestrutura de
um produto que lhes gera receita, e é uma declaração de desenho e intenção —
não um acordo de nível de serviço, uma garantia ou orientação jurídica. Onde
uma capacidade não está implementada, este documento diz isso em vez de
sugerir o contrário.

## Resumo

| Cenário | Efeito no software instalado | Status |
|---|---|---|
| Interrupção temporária do backend | Projetado para continuar funcionando por toda a janela offline, sem rede | Mecanismo implementado, validação ponta a ponta incompleta |
| Encerramento planejado do serviço | Depende de export de dados e artefatos | Planejado |
| Operador indisponível | Uma autoridade de recuperação em poder do desenvolvedor, utilizável sem nenhuma infraestrutura do Nexus | Mecanismo implementado, validação ponta a ponta incompleta |

Nenhuma das três linhas é uma capacidade concluída e verificada, e a diferença
entre elas é de natureza, não de grau. A primeira e a terceira têm mecanismos
implementados e aplicados em código hoje, com a validação ponta a ponta ainda
pendente. A segunda — o encerramento planejado — é uma direção de desenho sem
nenhuma implementação. O [Roadmap](ROADMAP.md) acompanha todas como trabalho
não concluído.

## 1. Por que uma interrupção não é uma negação

Um produto licenciado não pede permissão a um servidor para funcionar. A SDK
embarcada no produto carrega um blob **ProductData** com um keyring público e
verifica o certificado de ativação contra esse keyring localmente. A
verificação não precisa de rede. A rede é necessária apenas para *renovar* um
certificado, nunca para honrar um que já é válido.

Um certificado carrega dois prazos independentes:

- **`syncAfter`** — quando a thread em segundo plano começa a *tentar*
  renovar. Padrão: 24 horas.
- **`offlineValidUntil`** — o limite rígido que a própria SDK aplica. Padrão:
  30 dias; configurável por licença até 365 dias.

Eles não são deliberadamente o mesmo número, porque uma renovação que falha
não custa nada enquanto a janela offline não se esgota. O emissor do
certificado ainda aplica uma trava: a janela offline precisa sempre cobrir
**pelo menos duas tentativas inteiras de renovação**, de modo que uma única
sincronização com falha jamais seja o que nega uma licença.

A consequência prática que o desenho persegue: **o backend do Nexus pode ficar
inacessível por um período prolongado sem que clientes percam acesso a um
software que já ativaram.**

Dito com precisão, porque a distinção importa. O formato do certificado, os dois
prazos e a trava acima estão implementados e são aplicados pelo emissor hoje. O
que *não* está concluído é a validação ponta a ponta desse comportamento em
instalações reais — o [Roadmap](ROADMAP.md) marca "Operação offline e
verificações de plugin" como não concluído, e até que seja, a janela offline é
um mecanismo em vigor, não uma garantia demonstrada. Não planeje em cima de um
número específico de dias antes de esse item fechar.

### O que uma interrupção interrompe

Ser honesto sobre o limite importa mais do que a tranquilidade. Enquanto o
backend estiver inacessível:

- novas ativações não podem ser concedidas, e uma licença não pode ser movida
  para outra máquina;
- novas compras não podem ser processadas;
- novos releases não podem ser descobertos, baixados ou instalados;
- uma revogação não pode ser entregue — que é a mesma propriedade funcionando
  a favor do cliente, vista do outro lado.

Máquinas já ativadas continuam funcionando. Tudo o que exige uma decisão do
serviço espera pelo serviço.

## 2. Encerramento planejado

Se o serviço for descontinuado deliberadamente, a intenção é que o
desenvolvedor saia com tudo o que precisa para continuar atendendo os próprios
clientes:

- [ ] **Prazo de aviso e processo documentado,** incluindo o tratamento
  específico de licenças perpétuas e de assinatura.
- [ ] **Export versionado** de produtos, releases, licenças, entitlements,
  registros de ativação e o histórico de compras e auditoria necessário para
  atender clientes depois.
- [ ] **Artefatos de release.** Quando o desenvolvedor publica releases a
  partir de um repositório que lhe pertence, esses artefatos já estão sob
  controle dele. O trabalho planejado é tornar isso verdadeiro, documentado e
  verificável em toda configuração, e não em algumas.

Nada disso está disponível hoje.

## 3. Se o operador não estiver mais disponível

Este é o cenário que justifica uma política documentada, e o único que não pode
depender de alguém estar por perto para agir.

Um certificado de ativação é assinado com uma chave Ed25519 **com escopo de um
único tenant**, e quem a SDK confia é o keyring do produto, não o servidor.
Isso tem uma consequência direta: quem detém a metade privada de uma chave do
keyring de um produto pode emitir certificados que cópias já instaladas desse
produto aceitam, **sem nenhuma infraestrutura do Nexus envolvida**.

Essa autoridade é entregue ao desenvolvedor desde o início, de uma forma que
não depende da sobrevivência do Nexus, da cooperação do Nexus, nem de alguém
declarar uma emergência: **uma chave de recuperação gerada pelo desenvolvedor,
cuja metade privada nunca chega à infraestrutura do Nexus**, com apenas a
metade pública colocada no keyring do produto.

Dito sem rodeios, porque é o ponto do desenho: o Nexus não consegue usar essa
chave, e o desenvolvedor não precisa de permissão — nem de um operador vivo —
para usá-la.

### O que existe hoje

O mecanismo está implementado:

- o desenvolvedor gera um par Ed25519 na máquina que escolher e guarda a
  metade privada offline;
- apenas a metade pública é enviada, e um envio que contenha a metade privada
  é **recusado** — esse caminho existe para impedir o engano, não para
  descartar o segredo em silêncio;
- a metade pública passa a viajar no keyring do produto, ao lado da chave de
  assinatura, de modo que toda cópia já instalada do produto confia nela;
- ela nunca assina nada em operação normal. Os certificados são emitidos pela
  chave de assinatura; a de recuperação fica sem uso até ser necessária.

O que **não** está concluído é a verificação: emitir um certificado com a
chave de recuperação e ver um produto instalado aceitá-lo ainda não foi
demonstrado ponta a ponta em máquinas limpas, incluindo a metade negativa. Até
lá, isto é um mecanismo em vigor, não uma garantia demonstrada — a mesma
distinção feita para a janela offline na seção 1. Ver o
[Roadmap](ROADMAP.md).

A troca em si — como uma máquina pede um certificado e instala um sem nenhuma
rede — é o mesmo fluxo offline documentado para desenvolvedores no [guia de
ativação offline][offline] da SDK. Continuidade não é um mecanismo separado,
acoplado para emergências; é o caminho offline comum, usado quando não há mais
serviço com quem falar.

[offline]: https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/OFFLINE.md

### O que um caminho de recuperação faria e o que não faria

Ele permitiria ao desenvolvedor manter os clientes existentes funcionando e
ativar máquinas de reposição para licenças já vendidas.

Ele **não** daria continuidade ao serviço. Checkout, processamento de pedidos,
downloads hospedados, catálogo de plugins, emissão de licenças para novas
vendas e atualizações via MCNexus são propriedades de um serviço em operação, e
nenhum mecanismo criptográfico substitui um serviço. Um caminho de recuperação
é um piso sob os clientes que o desenvolvedor já tem, não um produto
substituto.

## 4. A verificação é o que torna isso real

Uma promessa de continuidade que nunca foi executada é marketing. Antes que
qualquer item acima seja apresentado como capacidade, e não como intenção, ele
precisa ser demonstrado em máquinas macOS e Windows limpas, com os serviços
hospedados indisponíveis — incluindo a metade negativa, de que certificados e
pacotes modificados, não assinados, expirados ou fora de escopo são
**rejeitados** pelo mesmo caminho.

Essa verificação é acompanhada no [Roadmap](ROADMAP.md) e não está concluída.

## 5. Alterações neste documento

Esta página é versionada junto com o restante da documentação pública, e
mudanças materiais são refletidas na data de última atualização. Dúvidas sobre
como ela se aplica a uma integração específica podem ser enviadas para
[hello@mcnexus.app](mailto:hello@mcnexus.app).
