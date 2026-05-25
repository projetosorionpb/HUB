# 🛠️ Manual de Uso: Gerenciador do Hub de Engenharia

Bem-vindo ao **Gerenciador "Antiburro" do Hub**. Esta ferramenta foi criada para acabar com a necessidade de digitar comandos complicados no terminal e evitar erros no `manifest.json`.

Com apenas alguns cliques, você consegue adicionar novos programas, atualizar os existentes e publicar tudo para os usuários.

---

## 🚀 Como Iniciar

1. Vá até a **raiz do seu projeto** (a pasta onde está o código-fonte do Hub).
2. Dê um **duplo clique** no arquivo chamado `GERENCIAR_HUB.bat`.
3. Uma tela preta (terminal) será aberta mostrando o menu principal com 3 opções principais.
4. Para escolher uma opção, digite o **número** correspondente (1, 2 ou 3) e aperte **Enter**.

---

## 1️⃣ Opção 1: Adicionar um NOVO Programa

Use esta opção quando você criou uma ferramenta do zero (uma planilha nova, um lisp novo, um `.exe` novo) e quer que ela apareça na vitrine do Hub.

**Passo a passo:**
1. Digite `1` no menu e aperte Enter.
2. O assistente fará algumas perguntas simples:
   - **Nome de Exibição:** O nome bonito que vai aparecer no botão do Hub (ex: `Gerador de Relatórios`).
   - **ID Interno:** Pode apenas dar Enter que ele cria automático (ex: `gerador_de_relatorios`).
   - **Descrição Curta:** O texto que aparece logo abaixo do nome.
   - **Tipo:** Digite o número correspondente ao tipo (exe, bat, html ou web).
   - **Nome do arquivo:** O nome exato do arquivo que o Hub deve "clicar" para abrir (ex: `iniciar.bat` ou `planilha.xlsx`).
   - **Cor:** Escolha a cor do botão.
3. **FIM DA TELA PRETA:** O assistente vai criar uma pastinha com o ID do seu módulo lá dentro da pasta `modules/`.
4. **Sua tarefa manual:** Vá até `modules/o_id_do_seu_modulo/` e **jogue todos os seus arquivos novos lá dentro**.

---

## 2️⃣ Opção 2: Atualizar a VERSÃO de um Programa Existente

Use esta opção quando você apenas modificou um programa que já existe (ex: consertou um bug na Automação CAD) e quer lançar essa melhoria.

**Passo a passo:**
1. Jogue os arquivos atualizados por cima dos velhos lá dentro da pasta do módulo (ex: `modules/automacao_cad/`).
2. Abra o `GERENCIAR_HUB.bat` e digite `2`.
3. Uma lista com todos os seus programas vai aparecer numerada.
4. Digite o número do programa que você quer atualizar (ex: `1` para Automação CAD).
5. O painel vai sugerir a próxima versão (se era 1.0.3, ele sugere 1.0.4). Se concordar, é só dar **Enter**.
6. **Pronto!** O seu `manifest.json` foi atualizado sozinho.

---

## 3️⃣ Opção 3: Empacotar e Enviar para o GitHub (A Mágica)

Use esta opção SEMPRE como **último passo**, após adicionar um programa novo (Opção 1) ou após atualizar a versão de um programa (Opção 2). É ela que envia tudo para os usuários!

**Passo a passo:**
1. Digite `3` no menu e aperte Enter.
2. O sistema vai perguntar: *"Qual será a TAG da Release no GitHub?"*.
   - **Atenção:** Você pode digitar o que quiser, por exemplo: `Ferramentas-24-05` ou `1.0.4`. **Guarde bem esse nome!**
3. O painel vai fazer todo o trabalho pesado sozinho:
   - Vai pegar os seus arquivos e transformar em `.zip`.
   - Vai escrever o seu `manifest.json` com os links milimetricamente perfeitos baseados na TAG que você digitou.
   - Vai usar o `git add`, `git commit` e `git push` sozinho. (Você não precisa mais abrir o VS Code para dar commit!).
4. **FIM DA TELA PRETA:** O assistente te dará o link do GitHub. Clique nele.

### O Passo Final no Navegador (GitHub)
1. Ao clicar no link que o painel gerou, a tela de "Nova Release" do GitHub vai abrir.
2. No campo **"Choose a tag"**, você deve digitar **EXATAMENTE** a mesma tag que você escreveu na tela preta (ex: `Ferramentas-24-05`).
3. Vá até a sua pasta local `dist/`. Lá estarão os novos arquivos `.zip`.
4. Arraste **todos os arquivos .zip** da pasta `dist/` para a área de anexo no final da página do GitHub.
5. Clique no botão verde **"Publish release"**.

🎉 **ACABOU!** Quando você ou seus usuários clicarem em "Verificar Atualizações" no Hub, a nova versão irá baixar imediatamente.
