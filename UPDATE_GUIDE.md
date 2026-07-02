# 🛠️ Manual de Uso: Painel de Controle do Hub

Bem-vindo ao **Painel de Controle do Hub**. Esta ferramenta (antigamente chamada de "Antiburro") foi criada para acabar com a necessidade de digitar comandos complicados no terminal e evitar erros humanos na edição do `manifest.json`.

Com apenas alguns cliques, você consegue adicionar novos programas, atualizar os existentes, remover ferramentas antigas e publicar tudo para os usuários.

---

## 🚀 Como Iniciar

1. Vá até a **raiz do seu projeto** (a pasta onde está o código-fonte do Hub).
2. Dê um **duplo clique** no arquivo chamado `GERENCIAR_HUB.bat`.
3. Uma tela preta (terminal) será aberta mostrando o menu principal com as opções.
4. Para escolher uma opção, digite o **número** correspondente (1, 2, 3 ou 4) e aperte **Enter**.

---

## 1️⃣ Opção 1: Adicionar um NOVO Programa

Use esta opção quando você criou uma ferramenta do zero (uma planilha nova, um lisp novo, um script python compilado `.exe` novo) e quer que ela apareça na vitrine do Hub.

**Passo a passo:**
1. Digite `1` no menu e aperte Enter.
2. O assistente fará algumas perguntas simples:
   - **Nome de Exibição:** O nome bonito que vai aparecer no botão do Hub (ex: `Gerador de Relatórios`).
   - **ID Interno:** Pode apenas dar Enter que ele cria automático em snake_case (ex: `gerador_de_relatorios`).
   - **Descrição Curta:** O texto que aparece logo abaixo do nome.
   - **Tipo:** Digite o número correspondente ao tipo (exe, bat, html ou web).
   - **Nome do arquivo:** O nome exato do arquivo que o Hub deve executar para abrir a ferramenta (ex: `iniciar.bat` ou `app.exe`).
   - **Cor:** Escolha a cor do botão a partir da paleta EPD-PB.
3. **FIM DO ASSISTENTE:** O sistema vai criar uma pastinha com o ID do seu módulo lá dentro da pasta `modules/` e atualizar o manifest local.
4. **Sua tarefa manual:** Vá até `modules/o_id_do_seu_modulo/` e **jogue todos os seus arquivos novos lá dentro**.

---

## 2️⃣ Opção 2: Atualizar a VERSÃO de um Programa Existente

Use esta opção quando você **já tem um programa cadastrado**, apenas modificou algum código dele (ex: consertou um bug na Automação CAD) e quer lançar essa melhoria para os usuários.

**Passo a passo:**
1. Jogue os arquivos atualizados por cima dos antigos lá dentro da pasta do módulo (ex: `modules/automacao_cad/`).
2. Abra o `GERENCIAR_HUB.bat` e digite `2`.
3. Uma lista com todos os seus programas vai aparecer numerada.
4. Digite o número do programa que você quer atualizar (ex: `1` para Automação CAD).
5. O painel vai sugerir a próxima versão (se era 1.0.3, ele sugere 1.0.4). Se concordar, é só dar **Enter**.
6. **Pronto!** O seu `manifest.json` foi atualizado sozinho.

---

## 3️⃣ Opção 3: Empacotar e Enviar para o GitHub (A Mágica)

Use esta opção SEMPRE como **último passo**, após adicionar um programa novo (Opção 1) ou após atualizar a versão de um programa (Opção 2). É ela que transforma os arquivos em ZIPs e prepara o repositório.

**Passo a passo:**
1. Digite `3` no menu e aperte Enter.
2. O sistema vai perguntar: *"Qual será a TAG da Release no GitHub?"*.
   - **Atenção:** A tag deve bater **exatamente** com o que você vai criar no GitHub. Exemplo: `v1.0.18-ferramentas`. **Guarde bem esse nome!**
3. O painel vai fazer o trabalho pesado sozinho:
   - Vai pegar os seus arquivos dentro de `modules/` e transformar em `.zip` dentro da pasta `dist/`.
   - Vai escrever o seu `manifest.json` injetando as URLs de download milimetricamente perfeitas baseadas na TAG que você digitou.
   - Vai usar o `git add`, `git commit` e `git push` automaticamente para jogar o manifest atualizado na branch `main`.
4. O assistente te dará o link do GitHub. Clique nele.

### O Passo Final no Navegador (GitHub)
1. Ao clicar no link, a tela de "Nova Release" do GitHub vai abrir.
2. No campo **"Choose a tag"**, você deve digitar **EXATAMENTE** a mesma tag que você escreveu no painel (ex: `v1.0.18-ferramentas`).
3. Vá até a sua pasta local `dist/`. Lá estarão os novos arquivos `.zip`.
4. Arraste **todos os arquivos .zip** da pasta `dist/` para a área de anexos (Assets) no final da página do GitHub.
5. Clique no botão verde **"Publish release"**.

---

## 4️⃣ Opção 4: REMOVER um Programa do Hub

Use esta opção se uma ferramenta ficou obsoleta e você deseja **arrancá-la** do Hub de todos os usuários da empresa.

**Passo a passo:**
1. Digite `4` no menu e aperte Enter.
2. Escolha o número da ferramenta que deseja excluir.
3. Confirme digitando 's'.
4. O painel irá:
   - Remover a ferramenta do `manifest.json`.
   - Deletar fisicamente a pasta de arquivos em `modules/`.
5. **Importante:** A remoção só vai refletir para os usuários quando você rodar a Opção 3 (Empacotar e Enviar) para atualizar o GitHub.
   Quando o Hub do usuário detectar que a ferramenta sumiu do manifest do GitHub, o Hub vai apagar a ferramenta do computador do usuário automaticamente.
