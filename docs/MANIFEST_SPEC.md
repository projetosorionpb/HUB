# Especificação do manifest.json

O arquivo `manifest.json` atua como o registro oficial dos módulos no Hub de Engenharia.

## Estrutura Base

```json
{
  "hub_version": "1.1.0",
  "hub_download_url": "https://github.com/...",
  "modules": {
    "module_id_1": { ... },
    "module_id_2": { ... }
  }
}
```

### Campos Globais

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `hub_version` | String | Versão mais recente do próprio executável do Hub. Usado para auto-update. |
| `hub_download_url` | String | Link direto (.exe ou .zip) para a última versão do Hub. |
| `modules` | Object | Dicionário contendo os módulos instalados, indexados pelo seu `ID interno`. |

---

## Estrutura do Objeto Módulo

O `ID interno` (chave no dicionário) deve ser em `snake_case` e deve bater **exatamente** com o nome da pasta do módulo em `modules/`.

```json
"conversor_pdf": {
  "version": "1.0.2",
  "display_name": "Conversor PDF",
  "description": "Converte PDF para DWG.",
  "type": "exe",
  "exe_name": "Conversor_PDF_para_DWG.exe",
  "port": 5077,
  "entry": "Conversor_PDF_para_DWG.exe",
  "color": "#ff8c00",
  "icon_svg": "<svg>...</svg>",
  "download_url": "https://github.com/.../conversor_pdf_v1.0.2.zip"
}
```

### Campos do Módulo

| Campo | Obrigatório | Tipo | Descrição |
|-------|-------------|------|-----------|
| `version` | Sim | String | Versão do módulo (Semantic Versioning recomendado). |
| `display_name` | Sim | String | Nome amigável que aparece no Card da UI. |
| `description` | Sim | String | Texto descritivo mostrado abaixo do título no Card. |
| `type` | Sim | String | Tipo de execução: `exe`, `bat`, `html`, `web`. |
| `exe_name` | Não | String | Nome do executável. Usado apenas se `type="exe"`. |
| `port` | Não | Int | Porta TCP usada para verificar se o `.exe` já está rodando. |
| `entry` | Sim | String | Caminho de entrada. Veja regras abaixo. |
| `color` | Sim | String | Cor hexadecimal do Card e do botão (ex: `#ef4444`). |
| `icon_svg` | Sim | String | Código SVG puro desenhado no ícone. Não use aspas duplas escapadas erroneamente. |
| `download_url` | Não | String | Link direto do `.zip` da release. Vazio apenas para `type="web"`. |

### Regras para o campo `entry`

O valor de `entry` varia conforme o `type`:
- `exe`: Nome do executável (ex: `app.exe`). Costuma ser igual a `exe_name`.
- `bat`: Nome do script de lote ou shell (ex: `iniciar.bat`).
- `html`: Nome do arquivo HTML (ex: `index.html`).
- `web`: URL completa incluindo protocolo (ex: `https://google.com`).

---

## Fluxo de Sincronização

Durante a inicialização ou quando o usuário clica em "Verificar Atualizações", o Hub executa o seguinte fluxo:
1. Faz parse do manifest local (`A`).
2. Faz HTTP GET no manifest do GitHub (`B`).
3. Para cada módulo em `B`:
   - Se a chave não existir em `A`: O módulo é marcado como **"new"** (Novo). O Hub baixa e instala.
   - Se a chave existir, mas `version` em `B` > `version` em `A`: Marcado como **"updates"**. Hub baixa e instala.
   - Se `version` for igual, mas metadados como `color` ou `display_name` mudaram: Marcado como **"metadata_updates"**. Hub atualiza o manifest local silenciosamente sem baixar ZIP.
4. Para cada módulo em `A`:
   - Se a chave não existir em `B`: Marcado como **"removed"**. Hub apaga os arquivos físicos e limpa a chave do manifest.
