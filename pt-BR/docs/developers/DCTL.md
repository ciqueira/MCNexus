# Conversão Nativa de DCTL para OFX

[English](../../../docs/developers/DCTL.md) · [Português](DCTL.md)

[Início](../../README.md) · [Guia do Desenvolvedor](../DEVELOPERS.md) · [Licenciamento](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

Empacote scripts DCTL (`.dctl`) e LUTs 3D em plugins OpenFX nativos (`.ofx.bundle`) para macOS (Metal) e Windows (OpenCL) com toda a infraestrutura da `NexKeyRuntime` já integrada, sem programar C++.

## 1. Visão Geral e Recursos Integrados

O pipeline DCTL para OFX da `NexKeyRuntime` compila sua matemática de cor e definições de interface em um plugin `.ofx.bundle` nativo, assinado e criptografado, sem gravar arquivos `.dctl` abertos em disco.

O `.ofx.bundle` gerado já sai pronto para distribuição no MCNexus com todos os recursos do núcleo ativos:

- **Licenciamento offline:** suporte às edições `Beta`, `Demo` (com marca d'água), `Trial` e `Full`, vinculação à máquina e ativação air-gap.
- **Updates e avisos in-app:** descoberta de novas versões, avisos do fabricante (`critical`, `recommended`, `info`) e instalação/rollback em 1 clique pelo aplicativo MCNexus.
- **Controle físico MIDI (`NexControl`):** parâmetros da DCTL mapeados diretamente para controladoras MIDI suportadas.
- **Checkout e entrega:** pronto para publicação gratuita no Discovery ou venda direta pelo Stripe (0% de comissão) sem código adicional.

O pré-processador DCTL suporta todos os **6** tipos padrão de `DEFINE_UI_PARAMS`:

1. `DCTLUI_SLIDER_FLOAT` (slider decimal com mínimo, máximo, padrão e passo)
2. `DCTLUI_VALUE_BOX` (campo numérico)
3. `DCTLUI_SLIDER_INT` (slider inteiro)
4. `DCTLUI_CHECK_BOX` (caixa de seleção booleana)
5. `DCTLUI_COMBO_BOX` (lista suspensa de opções)
6. `DCTLUI_COLOR_PICKER` (seletor de cor RGB)

## 2. Escolha de Nome e Slug Único

Antes de empacotar para distribuição, defina um nome claro de produto e um slug único em minúsculas (por exemplo, `film-print-halide`). Evite nomes genéricos que colidam com plugins já listados no [Discovery](../DISCOVERY.md) e mantenha o mesmo slug no GitHub Releases, no `ProductData` e nos templates do OpenKey.

## 3. Empacotamento Local e Validação no Sandbox

Você pode validar qualquer script `.dctl` localmente com as chaves prontas do sandbox em [sandbox/dctl-to-ofx](https://github.com/ciqueira/NexKeyRuntime/tree/main/sandbox/dctl-to-ofx). Executando com `--sandbox` dentro do repositório, a CLI `nexkeyctl` detecta automaticamente o runner da plataforma e `mcnexus-sandbox`, gravando em `./dist`:

```bash
# macOS (Metal)
nexkeyctl package-dctl \
  --input="MeuEfeito.dctl" \
  --name="Meu Efeito" \
  --sandbox

# Windows (OpenCL)
nexkeyctl.exe package-dctl ^
  --input="MeuEfeito.dctl" ^
  --name="Meu Efeito" ^
  --sandbox
```

Os pacotes `.ofx.bundle` gerados são assinados e criptografados. Copie o `.ofx.bundle` gerado para `/Library/OFX/Plugins/` (macOS) ou `C:\Program Files\Common Files\OFX\Plugins\` (Windows) para testar o modo `Demo` com marca d'água e a liberação `Full` usando as chaves do sandbox.

## 4. Publicação no Discovery (Trilha Gratuita/OSS ou Comercial)

1. **Trilha Gratuita ou Open-Source (Comunidade):** publique os pacotes `.zip` / `.pkg` no GitHub Releases e envie o [formulário de sugestão de plugin](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml) para listar seu plugin no [Discovery](../DISCOVERY.md).
2. **Trilha Comercial:** preencha o intake no [Guia do Desenvolvedor](../DEVELOPERS.md) para receber seu `tenant_id` e `ProductData` assinado, conectar sua conta Stripe (0% de comissão) e entregar instalações e atualizações em 1 clique pelo MCNexus.
