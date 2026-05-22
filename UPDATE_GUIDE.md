# Guia de Atualização de Módulos (Engineering Hub)

Este guia descreve o processo passo a passo para subir atualizações de ferramentas (como o Conversor PDF ou Substituidor de Blocos) para o Hub.

## Fluxo de Trabalho

### 1. Preparar os Novos Arquivos
Após realizar as alterações no código da ferramenta e gerar o novo executável:
- Vá até a pasta do módulo em: `modules/[nome_do_modulo]/`
- Substitua o arquivo `.exe` e a pasta `_internal` pelos novos arquivos gerados.

### 2. Incrementar a Versão
Abra o arquivo `manifest.json` na raiz do projeto e atualize a versão do módulo.
- **Exemplo:** Se a versão era `1.0.0`, mude para `1.0.1`.

```json
"conversor_pdf": {
  "version": "1.0.1",
  ...
}
```

### 3. Gerar o Pacote de Release
Execute o script de automação para empacotar o módulo e atualizar as URLs de download:

```powershell
python scripts/build_release.py
```

> [!NOTE]
> Este script criará um arquivo `.zip` na pasta `dist/` e atualizará o `manifest.json` com o link correto do GitHub.

### 4. Publicar no GitHub
Para que o Hub consiga baixar a atualização, você deve disponibilizar o arquivo:
1. Acesse o repositório no GitHub.
2. Vá em **Releases** > **Draft a new release**.
3. Em **Tag version**, use a versão exata que definiu (ex: `v1.0.1`).
4. Arraste o arquivo `.zip` gerado na pasta `dist/` para a área de anexos da Release.
5. Publique a Release.

### 5. Atualizar o Manifest no Repositório
Por fim, envie o `manifest.json` atualizado para a branch principal:

```powershell
git add manifest.json
git commit -m "feat: atualiza [nome do módulo] para v[versão]"
git push
```

---

## Como o Hub detecta a atualização?
O Hub verifica o `manifest.json` no repositório remoto sempre que é iniciado. Se a versão no GitHub for superior à versão instalada localmente na pasta `modules/`, o card da ferramenta mostrará automaticamente um botão **"Atualizar"**.
