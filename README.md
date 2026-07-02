# Hub de Engenharia — EPD-PB

> Plataforma centralizada (Launcher Desktop) para as ferramentas de engenharia da equipe **EPD-PB**.
> Desenvolvido em Python + PyQt6 com arquitetura extensível via `manifest.json`.

---

## 🏗️ Estrutura do Projeto

O sistema é dividido em duas partes principais: o aplicativo Hub (Python) e os Módulos (suas ferramentas em `modules/`).

```
HUB/
├── hub/                    # Código fonte do Launcher (Python/PyQt6)
│   ├── main.py             # Ponto de entrada
│   ├── config.py           # Constantes e configuração global
│   ├── core/               # Lógica de negócio
│   │   ├── launcher.py     # Lança os módulos conforme o tipo
│   │   ├── updater.py      # Sincroniza o manifest local com o GitHub
│   │   └── hub_self_updater.py # Baixa e substitui o próprio HubEngenharia.exe
│   └── ui/                 # Interface gráfica
│       ├── main_window.py
│       ├── card_widget.py
│       ├── update_dialog.py
│       └── toast_widget.py
├── scripts/                # Scripts utilitários e de pipeline
│   ├── admin_hub.py        # Menu interativo (Adicionar/Atualizar/Remover módulos)
│   └── build_release.py    # Empacota módulos e prepara release no GitHub
├── modules/                # Onde ficam os arquivos reais de cada ferramenta
├── docs/                   # Documentação técnica (Arquitetura, Especificação)
├── manifest.json           # Registro oficial dos módulos instalados localmente
├── requirements.txt        # Dependências Python
└── hub.spec                # Configuração de build do PyInstaller
```

---

## 🚀 Como Funciona o Hub?

O Hub não contém a lógica das ferramentas. Ele atua como um "Catálogo" e um "Gerenciador de Atualizações".

1. **Abertura**: Ao abrir, ele lê o `manifest.json` local e desenha os "Cards" das ferramentas.
2. **Atualização**: Em segundo plano, ele compara o `manifest.json` local com o `manifest.json` que está na branch `main` do GitHub.
3. **Download**: Se a versão do GitHub for maior, ele baixa o `.zip` da release, extrai na pasta `modules/`, atualiza o manifest local e avisa o usuário.
4. **Remoção**: Se um módulo existir localmente mas foi removido do GitHub, o Hub deleta a pasta e remove o card automaticamente.
5. **Auto-Update**: O Hub também verifica sua própria versão (`hub_version`) e pode se atualizar sozinho substituindo o executável.

---

## 🛠️ Tipos de Módulos Suportados

Você pode plugar qualquer tipo de ferramenta no Hub:

| Tipo | Descrição | Comportamento ao clicar em "ABRIR" |
|------|-----------|-------------------------------------|
| `exe` | Executáveis standalone (.exe) | Roda o `.exe` em background. Ideal para Flask empacotado. |
| `bat` | Scripts de Automação (.bat, .ps1) | Abre uma janela de terminal executando o script. |
| `html` | Páginas estáticas locais | Abre o arquivo HTML no navegador padrão do usuário. |
| `web` | Links externos / SaaS | Abre o link no navegador. Não faz download de ZIP. |

---

## 👨‍💻 Desenvolvedores: Como Adicionar uma Ferramenta

**Não edite o manifest.json na mão!** Use o assistente interativo:

1. **Execute o Painel de Controle:**
   Dê duplo clique em `GERENCIAR_HUB.bat` (ou rode `python scripts/admin_hub.py`).
2. **Opção [1]**: Siga os passos para cadastrar um novo programa.
3. **Cole seus arquivos**: Vá até a pasta `modules/<nome_do_seu_modulo>` e jogue os arquivos reais da sua ferramenta lá dentro.
4. **Opção [3]**: Empacote tudo e envie para o GitHub. (Ele vai zipar sua pasta e gerar os links no manifest).
5. **Crie a Release**: Vá no GitHub e publique a release subindo os `.zip` gerados na pasta `dist/`.

Para um guia passo a passo, leia o [UPDATE_GUIDE.md](UPDATE_GUIDE.md).

---

## ⚙️ Ambiente de Desenvolvimento

### 1. Clonar e Instalar Dependências

Requer **Python 3.10+**.

```bash
git clone https://github.com/projetosorionpb/HUB.git
cd HUB
pip install -r requirements.txt
```

### 2. Rodar o Hub em Modo Dev

```bash
python hub/main.py
```

### 3. Gerar o Executável (Build)

```bash
pyinstaller hub.spec
```
O arquivo gerado estará em `dist/HubEngenharia.exe`.

---

## 📚 Documentação Adicional

Para aprofundar na parte técnica, consulte:

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — Diagramas e fluxo completo do ecossistema.
- [MANIFEST_SPEC.md](docs/MANIFEST_SPEC.md) — Especificação formal dos campos do `manifest.json`.
- [UPDATE_GUIDE.md](UPDATE_GUIDE.md) — Manual prático de como operar as ferramentas administrativas.
- [CHANGELOG.md](CHANGELOG.md) — Histórico de versões do Hub.

---
*Hub de Engenharia — Desenvolvido por Valdeci Nunes — EPD-PB*
