# Política de Privacidade — Nexus

[English](../PRIVACY.md) · [Português](PRIVACY.md)

Última atualização: 13 de julho de 2026

Versão do documento: `nexus-privacy-2026-07-13`

Esta Política de Privacidade descreve como a plataforma Nexus coleta, utiliza, armazena e protege dados pessoais. O tratamento é realizado de acordo com a Lei Geral de Proteção de Dados brasileira (LGPD — Lei nº 13.709/2018) e, quando aplicável, com outras leis de proteção de dados.

A instalação, ativação ou uso do MCNexus, a solicitação de uma licença ou a
conclusão de uma compra pela plataforma implicam o reconhecimento de que esta
política foi disponibilizada. Cada produto também pode publicar uma política
própria aplicável ao mesmo fluxo.

## 1. Identificação do Controlador

O Nexus é desenvolvido e mantido por Magno Ciqueira, responsável pelo tratamento dos dados pessoais descritos nesta política.

Contato para assuntos de privacidade: [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br)

Em produtos próprios, a mesma pessoa pode controlar produto e plataforma,
mantendo as finalidades documentadas separadamente. Quando um tenant
independente usa o Nexus, esse tenant normalmente controla as finalidades de
clientes, comércio, licença, suporte e comunicação. O Nexus trata dados sob as
instruções do tenant nesses serviços e pode controlar separadamente dados
limitados necessários à segurança da plataforma, prevenção de abuso,
integridade do serviço e cumprimento legal. O contrato e a política do produto
devem identificar os papéis daquela implantação.

## 2. Bases Legais e Minimização de Dados

O tratamento necessário para fornecer, ativar, proteger e administrar licenças de software baseia-se principalmente na execução de contrato. Operações de segurança, prevenção a fraude, cumprimento de obrigações legais e exercício ou defesa de direitos podem utilizar outras bases legais aplicáveis.

O tratamento segue o princípio da minimização e abrange somente os dados necessários ao licenciamento, à entrega do produto, à segurança e ao suporte. Não são coletados dados pessoais sensíveis nem informações de navegação pessoal sem relação com essas finalidades.

Dados técnicos limitados podem ser tratados para segurança, estabilidade, diagnóstico e melhoria do serviço. Quando esses recursos forem utilizados, os dados envolvidos e suas finalidades serão descritos nesta política. Não há uso para publicidade comportamental.

## 3. Dados Tratados

- **Identificador de hardware (hardware fingerprint):** gerado localmente pelo aplicativo para vincular licenças node-locked ao dispositivo e impedir o uso simultâneo não autorizado. Os dados locais de licença são protegidos pelos mecanismos de segurança do sistema operacional, e a comunicação com os serviços de licenciamento utiliza HTTPS.
- **Endereço IP:** pode ser tratado durante ativações e solicitações ao serviço para segurança, limitação de requisições, prevenção a fraude e geolocalização aproximada por país ou região.
- **Nome e endereço de e-mail:** utilizados para identificar o titular da licença, entregar credenciais, prestar suporte e enviar comunicações transacionais relacionadas ao produto. Essas informações são fornecidas durante a compra, o cadastro ou o atendimento de suporte.
- **Dados técnicos da licença:** podem incluir chave de licença, produto, edição, versão, estado de ativação, identificador do dispositivo e datas associadas ao ciclo de vida da licença.
- **Referências de identidade:** podem incluir identificador da conta GitHub,
  usuário, e-mail verificado e estado OAuth de curta duração usado para
  autenticar claim ou compra. O Nexus não solicita acesso a repositórios
  privados para essa finalidade.
- **Registros de comércio e suporte:** podem incluir referências de Checkout
  Session, Payment Link, Price, pagamento, reembolso e disputa; valor, moeda,
  ambiente, snapshot da oferta, versão de documento aceita, fulfillment,
  vigência do suporte e campos de entrega de e-mail operacional.

O Nexus não coleta nem armazena números completos de cartão, informações bancárias ou credenciais completas de pagamento.

## 4. Acesso a Arquivos Locais e Permissões do Sistema

Para instalar e remover plugins, o MCNexus acessa somente as pastas necessárias ao aplicativo, ao licenciamento e à instalação de plugins OFX. No Windows, determinadas operações exigem privilégios administrativos para escrever em pastas do sistema, como `C:\Program Files\Common Files\OFX\Plugins`. No macOS, o sistema pode solicitar permissões equivalentes quando necessário.

O MCNexus não foi projetado para acessar, copiar ou transmitir projetos de vídeo, documentos ou outros arquivos pessoais. A comunicação com os serviços online limita-se às operações de licenciamento, atualização, download, segurança e suporte.

## 5. Retenção e Segurança

Os dados são mantidos pelo período necessário para fornecer e administrar licenças, prevenir fraude, atender solicitações dos titulares, cumprir obrigações legais e exercer ou defender direitos.

Os dados técnicos controlados diretamente pelo Nexus são excluídos ou anonimizados quando deixam de ser necessários, observados os prazos legais e operacionais aplicáveis. Os dados tratados por prestadores de serviço também seguem os respectivos prazos e procedimentos de retenção. Solicitações de exclusão serão encaminhadas e atendidas quando aplicáveis, considerando obrigações legais, prevenção a fraude e registros necessários à execução do contrato.

Credenciais e dados locais de licença são armazenados utilizando mecanismos de proteção disponibilizados pelo sistema operacional. Os dados transmitidos entre o aplicativo e o backend utilizam HTTPS.

## 6. Pagamentos

Licenças pagas, benefícios de Supporter e outras ofertas identificadas podem ser
processadas pelo Stripe ou parceiro mostrado na compra. O Nexus não recebe
números completos de cartão ou credenciais bancárias. O backend recebe somente
referências e dados do cliente necessários para verificar a transação, evitar
duplicidade, entregar o benefício, prestar suporte e tratar reembolsos ou
disputas.

## 7. Compartilhamento com Operadores

Os dados podem ser compartilhados, estritamente para as finalidades descritas acima, com:

- **GitHub:** autenticação de identidade para claims e entrada autenticada no
  Commerce;
- **Stripe e parceiros de checkout:** processamento e confirmação de pagamentos;
- **OpenKey/Nexus ou Cryptlex:** emissão, validação, ativação e gerenciamento de
  licença conforme a configuração do produto;
- **MailerLite, Mailchimp ou outro provedor identificado:** credenciais,
  mensagens transacionais, alertas de segurança, releases e manutenção do
  produto;
- **Cloudflare:** entrega das APIs, segurança de borda, prevenção de abuso,
  limitação e logs operacionais; e
- **hospedagem Neon/PostgreSQL:** registros da plataforma, licença, comércio e
  auditoria.

Esses provedores podem tratar dados fora do Brasil. Quando exigido pela legislação aplicável, são utilizados mecanismos adequados para transferências internacionais. Cada provedor também mantém uma política de privacidade específica.

O Nexus não vende nem aluga dados pessoais para publicidade.

Os provedores podem controlar independentemente partes de suas operações
próprias de conta, cobrança, fraude, segurança e cumprimento legal. Suas
políticas atuais se aplicam a essas operações.

## 8. Comunicações Operacionais e Marketing

Mensagens necessárias para entrega, ativação, segurança, compra, reembolso,
suporte e benefícios de release ou manutenção específicos do produto são
comunicações operacionais. Elas não autorizam publicidade de produtos não
relacionados.

Audiências opcionais de marketing devem usar escolha separada e mecanismo de
cancelamento. Retirar marketing opcional não impede mensagem necessária à
transação ativa, obrigação de segurança ou chamado de suporte. O grupo
operacional não pode ser convertido silenciosamente em consentimento de
marketing.

## 9. Direitos do Titular

Nos termos da legislação aplicável, o titular pode solicitar:

- confirmação da existência do tratamento;
- acesso aos dados;
- correção de dados incompletos, inexatos ou desatualizados;
- anonimização, bloqueio ou eliminação de dados desnecessários ou excessivos;
- informações sobre compartilhamentos;
- portabilidade, quando aplicável;
- revisão ou oposição a determinados tratamentos, quando cabível;
- eliminação dos dados, ressalvadas obrigações legais, contratuais, antifraude e de defesa de direitos.

O exercício desses direitos deve ser solicitado pelo e-mail [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br), com nome, endereço de e-mail cadastrado e, quando necessário, uma referência da licença. Informações adicionais podem ser solicitadas para confirmar a identidade do requerente.

Solicitações de privacidade não devem ser publicadas no GitHub Issues.

## 10. Crianças e Adolescentes

O Nexus é um produto profissional destinado a ilhas de pós-produção audiovisual e não é direcionado a menores de 18 anos. Não há coleta intencional de dados de crianças ou adolescentes.

## 11. Tratamento e Transferências Internacionais

O Nexus é operado a partir do Brasil e pode atender titulares localizados em outros países. Aplicam-se os requisitos de proteção de dados pertinentes a cada relação, incluindo, quando cabível, o GDPR para residentes do Espaço Econômico Europeu e do Reino Unido e as leis de privacidade aplicáveis a residentes da Califórnia.

Para titulares europeus, o tratamento necessário ao fornecimento da licença
baseia-se principalmente na execução do contrato. Transferências devem usar
mecanismos reconhecidos pela legislação aplicável. Operações sujeitas à lei
brasileira são avaliadas conforme a LGPD e o Regulamento de Transferência
Internacional da ANPD, incluindo salvaguardas contratuais quando exigidas.

O Nexus não vende nem compartilha informações pessoais para publicidade comportamental entre diferentes contextos. Titulares elegíveis podem solicitar acesso, correção ou exclusão pelos canais indicados nesta política.

## 12. Alterações

Esta política pode ser atualizada para refletir alterações no produto, nos prestadores de serviço ou nas exigências legais. A data da revisão mais recente será exibida no início do documento. Alterações relevantes poderão ser comunicadas pelos canais do aplicativo, do repositório ou pelos contatos cadastrados.

Quando houver aceite versionado, a versão disponibilizada para a transação será
registrada com ela. Isso não transforma silêncio ou uso de serviço não
relacionado em consentimento para marketing opcional.

## 13. Contato

- Privacidade: [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br)
- Suporte técnico: [github.com/ciqueira/MCNexus/issues](https://github.com/ciqueira/MCNexus/issues)
