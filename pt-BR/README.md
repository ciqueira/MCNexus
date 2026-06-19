<img src="../images/Nexus-Brand.png" alt="MCNexus" width="360">

---

[English](../README.md) · [Português](README.md)

**Instale, ative e mantenha plugins OFX em um só lugar.**

O MCNexus centraliza a instalação, o licenciamento e o controle de versões de plugins OFX para macOS e Windows. Para quem opera uma ilha de pós-produção, reduz etapas manuais e facilita atualizações e rollback. Para desenvolvedores, oferece uma infraestrutura padronizada de distribuição, licenciamento e entrega de versões.

<table>
  <tr>
    <td width="65%">
      <img src="../images/screen_app.png" alt="Aplicativo MCNexus" width="100%">
    </td>
    <td>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/windows-latest/MCNexus-Setup-Windows.exe">
        <img src="https://img.shields.io/badge/Baixar_para-Windows-0078D4?style=for-the-badge" alt="Baixar para Windows">
      </a>
      <br><br>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/macos-latest/MCNexus-macOS.dmg">
        <img src="https://img.shields.io/badge/Baixar_para-macOS-000000?style=for-the-badge" alt="Baixar para macOS">
      </a>
    </td>
  </tr>
</table>

> **Observação sobre a instalação:** as versões atuais para Windows ainda não possuem assinatura de código, e as versões para macOS ainda não possuem assinatura com certificado Apple Developer ID nem notarização pela Apple. O Microsoft Defender SmartScreen ou o macOS Gatekeeper podem exibir um alerta durante a instalação. As versões oficiais são distribuídas exclusivamente por este repositório.

## Plugins Integrados

Lista de plugins OFX integrados ao MCNexus.

[Ver plugins integrados](docs/DISCOVERY.md) · [Indicar um plugin](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml)

## Operação em Ilhas de Pós-Produção

O MCNexus cuida do ciclo de vida dos plugins instalados na estação de trabalho, da primeira ativação à instalação de uma versão anterior.

- **Instalação automática:** baixa e instala os arquivos OFX no diretório nativo definido pelo sistema operacional.
- **Atualização e rollback:** identifica versões publicadas e permite instalar uma atualização ou retornar a uma versão anterior disponível.
- **Ações independentes:** ativar uma licença, desativá-la, remover a chave local e remover os arquivos do plugin são operações diferentes.
- **Transferência entre computadores:** quando o computador anterior está acessível, a licença pode ser desativada nele antes da ativação em outra máquina. Liberações remotas e ajustes de ativações continuam sendo tratados pelo suporte.

[Começar pelo Guia de Operação](docs/USER_GUIDE.md)

## Para Desenvolvedores

O MCNexus inclui um pipeline de distribuição para plugins OFX comerciais e open source.

- **Distribuição flexível:** licenciamento comercial pelo Cryptlex ou distribuição aberta pelo OpenKey.
- **Automação de transações:** processamento de pagamentos pelo Stripe, geração automática da licença e envio de credenciais pelo MailerLite.
- **Gerenciamento de lançamentos:** artefatos para macOS e Windows, integração com GitHub Releases, canais Beta, Demo e Full para OpenKey, edições Demo e Full para distribuição comercial, downloads protegidos e notificações de atualização.

[Entender a integração para desenvolvedores](docs/DEVELOPERS.md)

## Compatibilidade do Aplicativo

- **macOS:** macOS 15 ou posterior, incluindo Apple Silicon e Macs Intel compatíveis.
- **Windows:** Windows 10/11 x64, com suporte ao Windows 11 ARM por emulação x64.
- **Linux:** planejado.

## Projeto

O MCNexus combina engenharia de software com experiência prática em pós-produção audiovisual. Desenvolvido de forma independente por [Magno Ciqueira](https://www.linkedin.com/in/ciqueira/) ([Instagram](https://www.instagram.com/magnociqueira/)), o projeto tem como objetivo reduzir fricções técnicas e manter infraestrutura para ferramentas comerciais e de código aberto.

## Documentação

- [Discovery](docs/DISCOVERY.md)
- [Guia de Operação](docs/USER_GUIDE.md)
- [Documentação para Desenvolvedores](docs/DEVELOPERS.md)
- [Perguntas Frequentes](docs/FAQ.md)
- [Roadmap](docs/ROADMAP.md)
- [Termos de Uso](TERMS.md)
- [Política de Privacidade](PRIVACY.md)

## Suporte

Problemas técnicos, dúvidas de ativação, relatórios de falhas e sugestões devem ser registrados pelos [formulários de suporte do GitHub](https://github.com/ciqueira/MCNexus/issues/new/choose). Inclua a versão do sistema operacional, a versão do MCNexus, o plugin afetado e os diagnósticos disponíveis.

O GitHub Issues é público e indexado por mecanismos de busca. Não publique uma chave de licença completa nem dados pessoais. Solicitações de privacidade devem ser enviadas para [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br).
