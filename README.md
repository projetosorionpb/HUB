# Hub de Engenharia

> Launcher desktop para as ferramentas da equipe **EPD-PB**.  
> Desenvolvido em Python + PyQt6.

---

## Estrutura do Projeto

```
HUB/
├── hub/
│   ├── main.py              # Entry point
│   ├── config.py            # Configurações (GitHub, módulos, caminhos)
│   ├── core/
│   │   ├── launcher.py      # Abertura de módulos Flask/HTML
│   │   └── updater.py       # Verificação e download de atualizações
│   └── ui/
│       ├── main_window.py   # Janela principal
│       ├── card_widget.py   # Card de cada ferramenta
│       └── update_dialog.py # Diálogo de progresso de atualização
├── scripts/
│   └── build_release.py     # Empacota módulos em .zip para release
├── manifest.json            # Versões instaladas de cada módulo
├── requirements.txt
└── hub.spec                 # Configuração do PyInstaller
```

---

## Configuração Rápida

### 1. Instalar dependências

```bash
pip install -r requirements.txt
```

### 2. Configurar o GitHub

Edite `hub/config.py`:

```python
GITHUB_USER = "seu_usuario"
GITHUB_REPO = "hub-engenharia"
```

### 3. Instalar os módulos

Os módulos devem ser extraídos em:

```
C:\Users\<seu_usuario>\HubEngenharia\modules\
    ├── substituidor_blocos\
    │       └── app.py          # Flask — porta 5000
    ├── conversor_pdf\
    │       └── app.py          # Flask — porta 5077
    ├── analise_qualidade\
    │       └── index.html      # HTML estático
    └── gerenciador_obras\
            └── index.html      # HTML estático
```

---

## Executar em modo de desenvolvimento

```bash
python hub/main.py
```

---

## Gerar o executável

```bash
pyinstaller hub.spec
```

O arquivo será gerado em `dist/HubEngenharia.exe`.

---

## Publicar uma atualização

1. **Atualize** o código do módulo desejado.
2. **Edite** o `manifest.json` com a nova versão (ex: `"version": "1.1.0"`).
3. **Empacote**:
   ```bash
   python scripts/build_release.py
   ```
4. **Crie uma Release** no GitHub com a tag `v1.1.0` e faça upload dos `.zip` gerados em `dist/`.
5. O hub detectará a atualização automaticamente na próxima abertura.

---

*Ferramenta desenvolvida por Valdeci Nunes — EPD-PB*
