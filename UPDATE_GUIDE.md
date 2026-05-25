# Guia de Atualização e Cadastro de Módulos (Engineering Hub)

Este guia descreve detalhadamente o passo a passo para **adicionar novos programas (módulos)** e **atualizar os já existentes** no seu Hub de Engenharia.

---

## 📂 Estrutura de Pastas do Projeto

Para que o Hub funcione corretamente, respeite a seguinte organização:

- `modules/` -> Pasta onde ficam os arquivos locais de cada módulo.
  - `conversor_pdf/` -> Pasta da ferramenta de conversão.
  - `substituidor_blocos/` -> Pasta da ferramenta de substituição.
  - `automacao_cad/` -> Pasta com scripts LISP e o instalador `.bat`.
- `manifest.json` -> O "cérebro" do Hub. Define nomes, versões, tipos de execução e links de download.
- `scripts/build_release.py` -> Script automatizado que empacota os módulos em arquivos `.zip` e atualiza o `manifest.json` com os links de download corretos do GitHub.

---

## ➕ Passo 1: Como Adicionar um Novo Programa (Automatizado)

Para cadastrar um novo programa de forma automática e rápida, siga estes passos simples:

### 1. Execute o Assistente Interativo
Abra o terminal na raiz do projeto e execute:
```powershell
python scripts/add_module.py
```
O assistente fará perguntas simples em português (Nome, Descrição, Tipo de ferramenta, Cor, etc.).
Ao finalizar, ele vai:
- Cadastrar a nova ferramenta automaticamente no `manifest.json`.
- Criar a pasta do módulo local em `modules/[nome_do_modulo]`.
- Gerar um arquivo base modelo pronto para uso (como um arquivo `.html` ou `.bat` inicial).

### 2. Substitua os arquivos locais pela sua ferramenta real
Vá na pasta criada em `modules/[nome_do_modulo]/` e coloque os arquivos reais do seu programa:
- Se for um programa em **Python/Flask compilado (.exe)**: Cole o executável real e a pasta `_internal` (substituindo o arquivo vazio criado pelo script).
- Se for um script em **lote (.bat)**: Cole o script real `.bat` e outros scripts de suporte (como scripts `.lsp`).
- Se for um arquivo **HTML estático**: Atualize a página `index.html` com o seu layout e código.

---

### 📝 Alternativa: Como Adicionar Manualmente (Sem o Script)

Caso prefira cadastrar manualmente sem o assistente, siga os passos abaixo:

1. **Criar a pasta:** Crie uma pasta sob `modules/[nome_do_modulo]` (nome limpo, minúsculo, sem acentos ou espaços).
2. **Copiar arquivos:** Cole os arquivos da ferramenta dentro da pasta.
3. **Editar o manifest.json:** Abra o `manifest.json` na raiz e crie o bloco de configuração da ferramenta dentro da chave `"modules"`:

```json
"meu_novo_programa": {
  "version": "1.0.0",
  "display_name": "Nome Lindo na Tela",
  "description": "Explicação breve do que este programa faz.",
  "type": "exe", // exe, bat, html ou web
  "exe_name": "MeuPrograma.exe", // (Só para exe) Nome do executável
  "port": 5080, // (Só para exe/flask) Porta TCP
  "entry": "MeuPrograma.exe", // Entrada (.exe, .bat, .html ou URL)
  "color": "#4f46e5", // Cor do card em Hexadecimal
  "icon_svg": "<svg>...</svg>", // Ícone em formato SVG
  "download_url": "" // Deixe vazio ("")
}
```

---

## 🔄 Passo 2: Como Atualizar um Programa Existente

Se você fez alterações em alguma ferramenta existente (como adicionar um novo script `.lsp` na pasta de Automação CAD, ou recompilar o `.exe` do Conversor PDF), siga este processo:

### 1. Substituir os arquivos locais
Vá na pasta correspondente em `modules/[nome_do_modulo]/` e substitua ou adicione os novos arquivos atualizados.
> *Exemplo:* Para atualizar os scripts de Automação CAD, vá em `modules/automacao_cad/`, adicione os novos arquivos `.lsp` e verifique se o arquivo `INSTALAR_SCRIPTS.bat` foi atualizado para instalá-los.

### 2. Incrementar a versão no `manifest.json`
Abra o `manifest.json` na raiz do projeto e altere o campo `"version"` do módulo que foi atualizado para um número maior.
- Se a versão antiga era `1.0.2`, mude para `1.0.3`.

```json
"automacao_cad": {
  "version": "1.0.3",
  ...
}
```

---

## 📦 Passo 3: Gerar os Pacotes e Publicar (Comum para Ambos)

Depois de cadastrar um novo programa ou atualizar um existente localmente, você deve empacotar e enviar para o GitHub para que os outros usuários recebam a atualização.

### 1. Executar o Script de Compilação
Abra o terminal (PowerShell ou CMD) na raiz do projeto e execute:
```powershell
python scripts/build_release.py
```

**O que este script faz?**
1. Ele criará arquivos `.zip` atualizados na pasta `dist/` para cada um dos módulos (ex: `dist/automacao_cad_v1.0.3.zip`).
2. Ele reescreverá o `manifest.json` local preenchendo automaticamente o campo `"download_url"` com o link apontando para a release correta do GitHub correspondente à versão configurada.

### 2. Enviar o `manifest.json` atualizado para o GitHub
Para que as outras pessoas vejam o botão **"Instalar"** ou **"Atualizar"** no Hub delas, o `manifest.json` na branch principal do GitHub precisa conter as novas versões.
Execute os seguintes comandos no terminal:
```powershell
git add manifest.json
git commit -m "feat: atualiza versao dos modulos no manifest"
git push origin main
```

### 3. Criar uma Release no GitHub
Para que o download dos arquivos `.zip` funcione, você precisa colocar esses arquivos na área de Downloads (Releases) do repositório:
1. Acesse o seu repositório no GitHub: **[projetosorionpb/HUB](https://github.com/projetosorionpb/HUB)**
2. No menu lateral direito, clique em **Releases** e depois em **Draft a new release** (ou acesse diretamente [github.com/projetosorionpb/HUB/releases/new](https://github.com/projetosorionpb/HUB/releases/new)).
3. No campo **Tag version**, digite a versão exata que você colocou no manifest com a letra **v** na frente (ex: `v1.0.2` ou `v1.0.3`). 
   > [!WARNING]
   > A tag precisa ser exatamente igual à versão definida no `manifest.json` precedida por `v`. Se a versão do módulo no manifest for `1.0.2`, a tag **deve** ser `v1.0.2`.
4. Defina um título para a Release (ex: `Release v1.0.2`).
5. Na área **Attach binaries...** (rodapé da página), arraste e solte o arquivo `.zip` correspondente que foi gerado na pasta `dist/` do seu computador.
6. Clique em **Publish release**.

---

## 🛠️ Como o Hub Atualiza nos Computadores dos Usuários?

1. Sempre que o usuário abre o **Hub**, o programa faz uma requisição silenciosa na internet para ler o `manifest.json` oficial da branch `main` do GitHub.
2. O Hub compara a versão local de cada ferramenta (que fica salva no `manifest.json` da máquina dele) com a versão informada no GitHub.
3. Se o GitHub tiver uma versão mais alta (ex: `1.0.3` no GitHub e `1.0.2` na máquina do usuário):
   - O botão no card da ferramenta muda automaticamente para **"Atualizar"** (ou **"Instalar"** se for uma ferramenta nova).
4. Ao clicar no botão, o Hub baixa o arquivo `.zip` da URL configurada, apaga a versão antiga local, descompacta a nova versão na pasta `modules/` e atualiza a versão no manifest local dele. Tudo de forma automática e segura!
